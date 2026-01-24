# frozen_string_literal: true

module Errordon
  class MediaTranscodeWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'media',
                    retry: 3,
                    dead: false,
                    lock: :until_executed

    def perform(media_attachment_id, options = {})
      return unless Rails.application.config.x.errordon_transcoding[:enabled]

      @attachment = MediaAttachment.find(media_attachment_id)
      @options = options.symbolize_keys

      return if @attachment.processing_status == 'completed'

      @attachment.update!(processing_status: 'processing')

      case @attachment.type
      when 'video'
        # Use dedicated service class
        Errordon::VideoTranscoderService.new(@attachment).call
      when 'audio'
        # Use dedicated service class
        Errordon::AudioTranscoderService.new(@attachment).call
      else
        Rails.logger.info "[Errordon] Skipping transcode for type: #{@attachment.type}"
        @attachment.update!(processing_status: 'completed')
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn "[Errordon] MediaAttachment #{media_attachment_id} not found"
    rescue StandardError => e
      Rails.logger.error "[Errordon] Transcode failed: #{e.message}"
      @attachment&.update!(processing_status: 'failed')
      raise e
    end

    private

    def process_video
      config = Rails.application.config.x.errordon_transcoding[:video]
      variants = {}

      # Generate thumbnail first
      if config[:thumbnail][:enabled]
        thumbnail_path = generate_thumbnail
        variants[:thumbnail] = upload_file(thumbnail_path, 'image/jpeg') if thumbnail_path
      end

      # Transcode to default (720p)
      if config[:variants][:default][:enabled]
        default_path = transcode_video(:default)
        variants[:default] = upload_file(default_path, 'video/mp4') if default_path
      end

      # Transcode to mobile (480p)
      if config[:variants][:mobile][:enabled]
        mobile_path = transcode_video(:mobile)
        variants[:mobile] = upload_file(mobile_path, 'video/mp4') if mobile_path
      end

      @attachment.update!(
        processing_status: 'completed',
        variants: variants
      )

      cleanup_temp_files
      delete_original_if_configured
    end

    def process_audio
      config = Rails.application.config.x.errordon_transcoding[:audio]
      variants = {}

      # Transcode to AAC
      output_path = transcode_audio
      variants[:default] = upload_file(output_path, 'audio/mp4') if output_path

      # Generate waveform
      if config[:generate_waveform]
        waveform = generate_waveform
        variants[:waveform] = waveform if waveform
      end

      @attachment.update!(
        processing_status: 'completed',
        variants: variants
      )

      cleanup_temp_files
      delete_original_if_configured
    end

    def transcode_video(variant)
      config = Rails.application.config.x.errordon_transcoding[:video][:variants][variant]
      input_path = download_original
      output_path = temp_path("#{variant}.mp4")

      resolution = config[:resolution]
      width, height = resolution.split('x').map(&:to_i)

      cmd = [
        'ffmpeg', '-y', '-i', input_path,
        '-c:v', 'libx264',
        '-preset', config[:preset],
        '-crf', config[:crf].to_s,
        '-maxrate', config[:bitrate],
        '-bufsize', "#{config[:bitrate].to_i * 2}k",
        '-vf', "scale=#{width}:#{height}:force_original_aspect_ratio=decrease,pad=#{width}:#{height}:(ow-iw)/2:(oh-ih)/2",
        '-c:a', 'aac',
        '-b:a', '128k',
        '-movflags', '+faststart',
        output_path
      ]

      run_ffmpeg(cmd)
      output_path
    end

    def transcode_audio
      config = Rails.application.config.x.errordon_transcoding[:audio]
      input_path = download_original
      output_path = temp_path('audio.m4a')

      cmd = [
        'ffmpeg', '-y', '-i', input_path,
        '-c:a', config[:codec],
        '-b:a', config[:bitrate],
        output_path
      ]

      run_ffmpeg(cmd)
      output_path
    end

    def generate_thumbnail
      config = Rails.application.config.x.errordon_transcoding[:video][:thumbnail]
      input_path = download_original
      output_path = temp_path('thumbnail.jpg')

      width, height = config[:resolution].split('x').map(&:to_i)

      cmd = [
        'ffmpeg', '-y', '-i', input_path,
        '-ss', config[:timestamp],
        '-vframes', '1',
        '-vf', "scale=#{width}:#{height}:force_original_aspect_ratio=decrease,pad=#{width}:#{height}:(ow-iw)/2:(oh-ih)/2",
        output_path
      ]

      run_ffmpeg(cmd)
      output_path
    end

    def generate_waveform
      # Simplified waveform generation - returns peak data
      input_path = download_original
      
      cmd = [
        'ffprobe', '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        input_path
      ]

      duration = `#{cmd.join(' ')}`.strip.to_f
      
      # Return basic waveform data structure
      {
        duration: duration,
        peaks: [] # Would be populated by actual waveform analysis
      }
    end

    def run_ffmpeg(cmd)
      Rails.logger.info "[Errordon] Running: #{cmd.join(' ')}"
      
      stdout, stderr, status = Open3.capture3(*cmd)
      
      unless status.success?
        Rails.logger.error "[Errordon] ffmpeg failed: #{stderr}"
        raise "ffmpeg failed: #{stderr}"
      end
      
      stdout
    end

    def download_original
      @original_path ||= begin
        path = temp_path("original_#{@attachment.id}")
        
        if @attachment.file.respond_to?(:download)
          File.binwrite(path, @attachment.file.download)
        else
          FileUtils.cp(@attachment.file.path, path)
        end
        
        path
      end
    end

    def upload_file(local_path, content_type)
      return nil unless File.exist?(local_path)
      
      # Return file info - actual upload handled by Mastodon's storage system
      {
        path: local_path,
        size: File.size(local_path),
        content_type: content_type
      }
    end

    def temp_path(filename)
      File.join(Dir.tmpdir, "errordon_#{@attachment.id}_#{filename}")
    end

    def cleanup_temp_files
      Dir.glob(File.join(Dir.tmpdir, "errordon_#{@attachment.id}_*")).each do |f|
        FileUtils.rm_f(f)
      end
    end

    def delete_original_if_configured
      return unless Rails.application.config.x.errordon_transcoding[:storage][:delete_originals]
      
      @attachment.file.purge if @attachment.file.attached?
    end
  end
end
