# frozen_string_literal: true

module Errordon
  class VideoTranscoderService
    include Redisable

    VARIANTS = {
      default: {
        resolution: '1280x720',
        bitrate: '2500k',
        preset: 'medium',
        crf: 23
      },
      mobile: {
        resolution: '854x480',
        bitrate: '1000k',
        preset: 'fast',
        crf: 26
      }
    }.freeze

    THUMBNAIL_CONFIG = {
      resolution: '400x225',
      timestamp: '00:00:01'
    }.freeze

    def initialize(media_attachment)
      @attachment = media_attachment
      @config = Rails.application.config.x.errordon_transcoding
    end

    def call
      return unless @config[:enabled]
      return unless @attachment.video?

      Rails.logger.info "[Errordon] Starting video transcode for attachment #{@attachment.id}"

      results = {}

      # Generate thumbnail
      results[:thumbnail] = generate_thumbnail

      # Transcode variants
      VARIANTS.each do |name, settings|
        next unless variant_enabled?(name)

        results[name] = transcode_variant(name, settings)
      end

      # Update attachment
      @attachment.update!(
        processing_status: 'completed',
        variants: results,
        transcoded_size: calculate_total_size(results)
      )

      cleanup_temp_files
      results
    rescue StandardError => e
      Rails.logger.error "[Errordon] Video transcode failed: #{e.message}"
      @attachment.update!(processing_status: 'failed')
      raise e
    end

    private

    def variant_enabled?(name)
      return true if name == :default

      @config.dig(:video, :variants, name, :enabled) != false
    end

    def transcode_variant(name, settings)
      input_path = download_original
      output_path = temp_path("#{name}.mp4")

      width, height = settings[:resolution].split('x').map(&:to_i)

      command = build_ffmpeg_command(
        input: input_path,
        output: output_path,
        width: width,
        height: height,
        bitrate: settings[:bitrate],
        preset: settings[:preset],
        crf: settings[:crf]
      )

      execute_ffmpeg(command)

      {
        path: output_path,
        size: File.size(output_path),
        resolution: settings[:resolution],
        bitrate: settings[:bitrate]
      }
    end

    def generate_thumbnail
      input_path = download_original
      output_path = temp_path('thumbnail.jpg')

      width, height = THUMBNAIL_CONFIG[:resolution].split('x').map(&:to_i)

      command = [
        'ffmpeg', '-y', '-i', input_path,
        '-ss', THUMBNAIL_CONFIG[:timestamp],
        '-vframes', '1',
        '-vf', "scale=#{width}:#{height}:force_original_aspect_ratio=decrease,pad=#{width}:#{height}:(ow-iw)/2:(oh-ih)/2",
        '-q:v', '2',
        output_path
      ]

      execute_ffmpeg(command)

      {
        path: output_path,
        size: File.size(output_path),
        resolution: THUMBNAIL_CONFIG[:resolution]
      }
    end

    def build_ffmpeg_command(input:, output:, width:, height:, bitrate:, preset:, crf:)
      [
        'ffmpeg', '-y', '-i', input,
        '-c:v', 'libx264',
        '-preset', preset,
        '-crf', crf.to_s,
        '-maxrate', bitrate,
        '-bufsize', "#{bitrate.to_i * 2}k",
        '-vf', "scale=#{width}:#{height}:force_original_aspect_ratio=decrease,pad=#{width}:#{height}:(ow-iw)/2:(oh-ih)/2",
        '-c:a', 'aac',
        '-b:a', '128k',
        '-movflags', '+faststart',
        output
      ]
    end

    def execute_ffmpeg(command)
      Rails.logger.debug "[Errordon] Executing: #{command.join(' ')}"

      stdout, stderr, status = Open3.capture3(*command)

      unless status.success?
        raise "ffmpeg failed: #{stderr}"
      end

      stdout
    end

    def download_original
      @original_path ||= begin
        path = temp_path("original_#{@attachment.id}#{File.extname(@attachment.file_file_name)}")

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
      File.join(Dir.tmpdir, "errordon_transcode_#{@attachment.id}_#{filename}")
    end

    def cleanup_temp_files
      Dir.glob(File.join(Dir.tmpdir, "errordon_transcode_#{@attachment.id}_*")).each do |f|
        FileUtils.rm_f(f)
      end
    end

    def calculate_total_size(results)
      results.values.sum { |v| v[:size] || 0 }
    end
  end
end
