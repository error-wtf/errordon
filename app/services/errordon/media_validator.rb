# frozen_string_literal: true

module Errordon
  class MediaValidator
    # Secure media validation using ffprobe
    
    ALLOWED_VIDEO_CONTAINERS = %w[mp4 webm mkv mov avi].freeze
    ALLOWED_AUDIO_CONTAINERS = %w[mp3 m4a ogg flac wav aac opus].freeze
    ALLOWED_IMAGE_FORMATS = %w[jpg jpeg png gif webp].freeze

    MAX_VIDEO_DURATION = 3600      # 1 hour max
    MAX_AUDIO_DURATION = 7200      # 2 hours max
    MAX_RESOLUTION = 7680          # 8K max
    MAX_FRAME_RATE = 120
    MAX_BIT_DEPTH = 16

    class ValidationError < StandardError; end
    class CorruptedFileError < ValidationError; end
    class UnsupportedFormatError < ValidationError; end
    class ExcessiveDimensionsError < ValidationError; end

    def initialize(file_path, expected_type: nil)
      @file_path = file_path
      @expected_type = expected_type
      @metadata = nil
      @errors = []
    end

    def valid?
      validate!
      @errors.empty?
    rescue ValidationError
      false
    end

    def validate!
      raise ValidationError, "File not found: #{@file_path}" unless File.exist?(@file_path)
      raise ValidationError, "Empty file" if File.zero?(@file_path)

      @metadata = probe_file

      validate_format!
      validate_streams!
      validate_duration!
      validate_dimensions!
      validate_no_embedded_data!

      raise ValidationError, @errors.join('; ') if @errors.any?

      true
    end

    def metadata
      @metadata ||= probe_file
    end

    private

    def probe_file
      command = [
        'ffprobe',
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        '-show_error',
        @file_path
      ]

      stdout, stderr, status = Open3.capture3(*command)

      unless status.success?
        raise CorruptedFileError, "ffprobe failed: #{stderr}"
      end

      JSON.parse(stdout)
    rescue JSON::ParserError => e
      raise CorruptedFileError, "Invalid ffprobe output: #{e.message}"
    end

    def validate_format!
      format_name = @metadata.dig('format', 'format_name')&.split(',')&.first

      return if format_name.nil?

      case @expected_type
      when :video
        unless ALLOWED_VIDEO_CONTAINERS.any? { |c| format_name.include?(c) }
          @errors << "Unsupported video format: #{format_name}"
        end
      when :audio
        unless ALLOWED_AUDIO_CONTAINERS.any? { |c| format_name.include?(c) }
          @errors << "Unsupported audio format: #{format_name}"
        end
      when :image
        unless ALLOWED_IMAGE_FORMATS.any? { |c| format_name.include?(c) }
          @errors << "Unsupported image format: #{format_name}"
        end
      end
    end

    def validate_streams!
      streams = @metadata['streams'] || []

      return if streams.empty?

      video_streams = streams.select { |s| s['codec_type'] == 'video' }
      audio_streams = streams.select { |s| s['codec_type'] == 'audio' }
      data_streams = streams.select { |s| s['codec_type'] == 'data' }

      # Check for suspicious stream counts
      if video_streams.size > 4
        @errors << "Too many video streams: #{video_streams.size}"
      end

      if audio_streams.size > 8
        @errors << "Too many audio streams: #{audio_streams.size}"
      end

      # Data streams might contain malicious content
      if data_streams.any?
        data_streams.each do |stream|
          codec = stream['codec_name']
          if %w[bin_data text mjpeg].include?(codec)
            Rails.logger.warn "[Errordon::MediaValidator] Data stream detected: #{codec}"
          end
        end
      end

      # Validate individual streams
      video_streams.each { |s| validate_video_stream!(s) }
      audio_streams.each { |s| validate_audio_stream!(s) }
    end

    def validate_video_stream!(stream)
      codec = stream['codec_name']
      allowed_codecs = %w[h264 hevc vp8 vp9 av1 mpeg4 theora mjpeg gif png]

      unless allowed_codecs.include?(codec)
        @errors << "Unsupported video codec: #{codec}"
      end

      # Check for suspicious profiles
      profile = stream['profile']
      if profile && profile.downcase.include?('unknown')
        Rails.logger.warn "[Errordon::MediaValidator] Unknown video profile: #{profile}"
      end
    end

    def validate_audio_stream!(stream)
      codec = stream['codec_name']
      allowed_codecs = %w[aac mp3 opus vorbis flac pcm_s16le pcm_s24le pcm_f32le alac]

      unless allowed_codecs.include?(codec)
        @errors << "Unsupported audio codec: #{codec}"
      end

      # Check sample rate
      sample_rate = stream['sample_rate'].to_i
      if sample_rate > 192_000
        @errors << "Excessive sample rate: #{sample_rate}"
      end

      # Check bit depth
      bits = stream['bits_per_sample'].to_i
      if bits > MAX_BIT_DEPTH && bits != 24 && bits != 32
        @errors << "Unsupported bit depth: #{bits}"
      end
    end

    def validate_duration!
      duration = @metadata.dig('format', 'duration').to_f

      case @expected_type
      when :video
        if duration > MAX_VIDEO_DURATION
          @errors << "Video too long: #{duration}s > #{MAX_VIDEO_DURATION}s"
        end
      when :audio
        if duration > MAX_AUDIO_DURATION
          @errors << "Audio too long: #{duration}s > #{MAX_AUDIO_DURATION}s"
        end
      end

      if duration.negative?
        @errors << "Invalid duration: #{duration}"
      end
    end

    def validate_dimensions!
      streams = @metadata['streams'] || []
      video_stream = streams.find { |s| s['codec_type'] == 'video' }

      return unless video_stream

      width = video_stream['width'].to_i
      height = video_stream['height'].to_i
      frame_rate = eval_frame_rate(video_stream['r_frame_rate'])

      if width > MAX_RESOLUTION || height > MAX_RESOLUTION
        @errors << "Resolution too large: #{width}x#{height}"
      end

      if width.zero? || height.zero?
        @errors << "Invalid dimensions: #{width}x#{height}"
      end

      if frame_rate > MAX_FRAME_RATE
        @errors << "Frame rate too high: #{frame_rate}"
      end

      # Check for decompression bomb (very large uncompressed size)
      file_size = @metadata.dig('format', 'size').to_i
      uncompressed_estimate = width * height * 3 * frame_rate * @metadata.dig('format', 'duration').to_f

      if file_size.positive? && uncompressed_estimate / file_size > 1000
        @errors << "Potential decompression bomb detected"
      end
    end

    def eval_frame_rate(rate_string)
      return 0 if rate_string.blank?

      if rate_string.include?('/')
        num, den = rate_string.split('/').map(&:to_f)
        return 0 if den.zero?

        num / den
      else
        rate_string.to_f
      end
    rescue StandardError
      0
    end

    def validate_no_embedded_data!
      # Check format tags for suspicious metadata
      tags = @metadata.dig('format', 'tags') || {}

      suspicious_keys = %w[script comment description]
      suspicious_keys.each do |key|
        value = tags[key].to_s
        next if value.blank?

        if value.match?(/<script|javascript:|vbscript:|on\w+=/i)
          @errors << "Suspicious metadata in #{key}"
        end
      end
    end
  end
end
