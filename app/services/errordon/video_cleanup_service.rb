# frozen_string_literal: true

require 'open3'
require 'fileutils'

module Errordon
  class VideoCleanupService
    include Redisable

    # 480p settings for space-saving re-encode
    CLEANUP_SETTINGS = {
      resolution: '854x480',
      bitrate: '800k',
      preset: 'slow',      # Better compression
      crf: 28,             # Higher = smaller file
      audio_bitrate: '96k'
    }.freeze

    class << self
      def config
        @config ||= {
          enabled: ENV.fetch('ERRORDON_VIDEO_CLEANUP_ENABLED', 'true') == 'true',
          days_threshold: ENV.fetch('ERRORDON_VIDEO_CLEANUP_DAYS', '7').to_i,
          min_original_size_mb: ENV.fetch('ERRORDON_VIDEO_CLEANUP_MIN_SIZE_MB', '10').to_i,
          batch_size: ENV.fetch('ERRORDON_VIDEO_CLEANUP_BATCH_SIZE', '10').to_i,
          dry_run: ENV.fetch('ERRORDON_VIDEO_CLEANUP_DRY_RUN', 'false') == 'true'
        }
      end

      def enabled?
        config[:enabled]
      end

      def run!(dry_run: nil)
        dry_run = config[:dry_run] if dry_run.nil?
        
        stats = {
          processed: 0,
          skipped: 0,
          failed: 0,
          space_saved_bytes: 0,
          started_at: Time.current
        }

        videos_to_cleanup.find_each(batch_size: config[:batch_size]) do |attachment|
          result = new(attachment, dry_run: dry_run).call
          
          if result[:success]
            stats[:processed] += 1
            stats[:space_saved_bytes] += result[:space_saved] || 0
          elsif result[:skipped]
            stats[:skipped] += 1
          else
            stats[:failed] += 1
          end
        end

        stats[:finished_at] = Time.current
        stats[:duration_seconds] = (stats[:finished_at] - stats[:started_at]).to_i
        stats[:space_saved_mb] = (stats[:space_saved_bytes] / 1.megabyte.to_f).round(2)

        log_stats(stats)
        stats
      end

      def videos_to_cleanup
        threshold_date = config[:days_threshold].days.ago
        min_size = config[:min_original_size_mb].megabytes

        MediaAttachment
          .where(type: :video)
          .where(processing_complete: true)
          .where('created_at < ?', threshold_date)
          .where('file_file_size > ?', min_size)
          .where(errordon_shrunk: [false, nil])
          .order(created_at: :asc)
      end

      def stats
        threshold_date = config[:days_threshold].days.ago
        min_size = config[:min_original_size_mb].megabytes

        eligible = videos_to_cleanup
        total_videos = MediaAttachment.where(type: :video).count
        already_shrunk = MediaAttachment.where(type: :video, errordon_shrunk: true).count

        {
          config: config,
          total_videos: total_videos,
          eligible_for_cleanup: eligible.count,
          eligible_size_mb: (eligible.sum(:file_file_size) / 1.megabyte.to_f).round(2),
          already_shrunk: already_shrunk,
          threshold_date: threshold_date
        }
      end

      private

      def log_stats(stats)
        Rails.logger.info "[Errordon VideoCleanup] Completed: " \
                          "processed=#{stats[:processed]}, " \
                          "skipped=#{stats[:skipped]}, " \
                          "failed=#{stats[:failed]}, " \
                          "space_saved=#{stats[:space_saved_mb]}MB, " \
                          "duration=#{stats[:duration_seconds]}s"
      end
    end

    def initialize(attachment, dry_run: false)
      @attachment = attachment
      @dry_run = dry_run
      @original_size = attachment.file_file_size
    end

    def call
      return skip_result('Cleanup disabled') unless self.class.enabled?
      return skip_result('Not a video') unless @attachment.video?
      return skip_result('Already shrunk') if @attachment.errordon_shrunk?
      return skip_result('Too small') if @original_size < self.class.config[:min_original_size_mb].megabytes
      return skip_result('Too recent') if @attachment.created_at > self.class.config[:days_threshold].days.ago

      if @dry_run
        return dry_run_result
      end

      shrink_video!
    rescue StandardError => e
      Rails.logger.error "[Errordon VideoCleanup] Failed for attachment #{@attachment.id}: #{e.message}"
      { success: false, error: e.message }
    end

    private

    def shrink_video!
      Rails.logger.info "[Errordon VideoCleanup] Shrinking video #{@attachment.id} " \
                        "(#{(@original_size / 1.megabyte.to_f).round(2)}MB)"

      input_path = download_original
      output_path = temp_path('shrunk.mp4')

      # Transcode to 480p
      execute_shrink(input_path, output_path)

      new_size = File.size(output_path)
      space_saved = @original_size - new_size

      # Only replace if we actually saved space
      if new_size >= @original_size
        Rails.logger.info "[Errordon VideoCleanup] Skipping #{@attachment.id}: " \
                          "shrunk version not smaller (#{new_size} >= #{@original_size})"
        cleanup_temp_files
        @attachment.update!(errordon_shrunk: true, errordon_shrunk_at: Time.current)
        return skip_result('Shrunk version not smaller')
      end

      # Replace original with shrunk version
      replace_original!(output_path, new_size)

      Rails.logger.info "[Errordon VideoCleanup] Shrunk video #{@attachment.id}: " \
                        "#{(@original_size / 1.megabyte.to_f).round(2)}MB → " \
                        "#{(new_size / 1.megabyte.to_f).round(2)}MB " \
                        "(saved #{(space_saved / 1.megabyte.to_f).round(2)}MB)"

      cleanup_temp_files

      {
        success: true,
        attachment_id: @attachment.id,
        original_size: @original_size,
        new_size: new_size,
        space_saved: space_saved
      }
    end

    def execute_shrink(input_path, output_path)
      settings = CLEANUP_SETTINGS
      width, height = settings[:resolution].split('x').map(&:to_i)

      command = [
        'ffmpeg', '-y', '-i', input_path,
        '-c:v', 'libx264',
        '-preset', settings[:preset],
        '-crf', settings[:crf].to_s,
        '-maxrate', settings[:bitrate],
        '-bufsize', "#{settings[:bitrate].to_i * 2}k",
        '-vf', "scale='min(#{width},iw)':min'(#{height},ih)':force_original_aspect_ratio=decrease",
        '-c:a', 'aac',
        '-b:a', settings[:audio_bitrate],
        '-movflags', '+faststart',
        '-threads', '2',
        output_path
      ]

      Rails.logger.debug "[Errordon VideoCleanup] Executing: #{command.join(' ')}"

      stdout, stderr, status = Open3.capture3(*command)

      unless status.success?
        raise "ffmpeg failed: #{stderr}"
      end

      stdout
    end

    def replace_original!(new_file_path, new_size)
      # Update file
      File.open(new_file_path, 'rb') do |file|
        @attachment.file = file
      end

      # Update metadata
      @attachment.update!(
        file_file_size: new_size,
        errordon_shrunk: true,
        errordon_shrunk_at: Time.current,
        errordon_original_size: @original_size
      )
    end

    def download_original
      @original_path ||= begin
        path = temp_path("original#{File.extname(@attachment.file_file_name)}")

        if @attachment.file.respond_to?(:download)
          File.binwrite(path, @attachment.file.download)
        elsif @attachment.file.respond_to?(:path)
          FileUtils.cp(@attachment.file.path, path)
        else
          raise 'Cannot access original file'
        end

        path
      end
    end

    def temp_path(filename)
      File.join(Dir.tmpdir, "errordon_cleanup_#{@attachment.id}_#{filename}")
    end

    def cleanup_temp_files
      Dir.glob(File.join(Dir.tmpdir, "errordon_cleanup_#{@attachment.id}_*")).each do |f|
        FileUtils.rm_f(f)
      end
    end

    def skip_result(reason)
      { success: false, skipped: true, reason: reason }
    end

    def dry_run_result
      estimated_saving = (@original_size * 0.6).to_i # Estimate ~40% reduction

      {
        success: true,
        dry_run: true,
        attachment_id: @attachment.id,
        original_size: @original_size,
        estimated_new_size: @original_size - estimated_saving,
        estimated_space_saved: estimated_saving
      }
    end
  end
end
