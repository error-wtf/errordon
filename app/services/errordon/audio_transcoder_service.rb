# frozen_string_literal: true

module Errordon
  class AudioTranscoderService
    AUDIO_CONFIG = {
      codec: 'aac',
      bitrate: '128k',
      format: 'm4a'
    }.freeze

    def initialize(media_attachment)
      @attachment = media_attachment
      @config = Rails.application.config.x.errordon_transcoding
    end

    def call
      return unless @config[:enabled]
      return unless @attachment.audio?

      Rails.logger.info "[Errordon] Starting audio transcode for attachment #{@attachment.id}"

      results = {}

      # Transcode to AAC
      results[:default] = transcode_audio

      # Generate waveform data
      if @config.dig(:audio, :generate_waveform)
        results[:waveform] = generate_waveform
      end

      @attachment.update!(
        processing_status: 'completed',
        variants: results,
        transcoded_size: results[:default][:size]
      )

      cleanup_temp_files
      results
    rescue StandardError => e
      Rails.logger.error "[Errordon] Audio transcode failed: #{e.message}"
      @attachment.update!(processing_status: 'failed')
      raise e
    end

    private

    def transcode_audio
      input_path = download_original
      output_path = temp_path("audio.#{AUDIO_CONFIG[:format]}")

      command = [
        'ffmpeg', '-y', '-i', input_path,
        '-c:a', AUDIO_CONFIG[:codec],
        '-b:a', AUDIO_CONFIG[:bitrate],
        '-vn', # No video
        output_path
      ]

      execute_ffmpeg(command)

      {
        path: output_path,
        size: File.size(output_path),
        codec: AUDIO_CONFIG[:codec],
        bitrate: AUDIO_CONFIG[:bitrate]
      }
    end

    def generate_waveform
      input_path = download_original

      # Get duration
      duration_cmd = [
        'ffprobe', '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        input_path
      ]

      duration = `#{duration_cmd.join(' ')}`.strip.to_f

      # Generate peaks using ffmpeg
      peaks = extract_audio_peaks(input_path, duration)

      {
        duration: duration,
        peaks: peaks,
        sample_rate: 100 # Peaks per second
      }
    end

    def extract_audio_peaks(input_path, duration)
      return [] if duration.zero?

      # Sample ~200 points for waveform visualization
      num_samples = [200, (duration * 10).to_i].min
      interval = duration / num_samples

      peaks = []
      num_samples.times do |i|
        timestamp = i * interval
        peak = get_peak_at(input_path, timestamp)
        peaks << peak
      end

      # Normalize peaks to 0-1 range
      max_peak = peaks.max || 1
      peaks.map { |p| (p / max_peak.to_f).round(3) }
    end

    def get_peak_at(input_path, timestamp)
      cmd = [
        'ffmpeg', '-ss', timestamp.to_s, '-i', input_path,
        '-t', '0.1', '-af', 'volumedetect',
        '-f', 'null', '-'
      ]

      _, stderr, = Open3.capture3(*cmd)

      # Parse max_volume from ffmpeg output
      if stderr =~ /max_volume: ([-\d.]+) dB/
        db = Regexp.last_match(1).to_f
        # Convert dB to linear scale (0-1)
        10**(db / 20.0)
      else
        0.5
      end
    rescue StandardError
      0.5
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
      File.join(Dir.tmpdir, "errordon_audio_#{@attachment.id}_#{filename}")
    end

    def cleanup_temp_files
      Dir.glob(File.join(Dir.tmpdir, "errordon_audio_#{@attachment.id}_*")).each do |f|
        FileUtils.rm_f(f)
      end
    end
  end
end
