# frozen_string_literal: true

# Errordon Transcoding Configuration
# Settings for video/audio transcoding pipeline
#
# ENV variables:
#   ERRORDON_TRANSCODING_ENABLED - Enable transcoding (default: false)
#   ERRORDON_TRANSCODE_720P - Enable 720p variant (default: true)
#   ERRORDON_TRANSCODE_480P - Enable 480p mobile variant (default: true)
#   ERRORDON_DELETE_ORIGINALS - Delete original after transcode (default: false)

Rails.application.config.x.errordon_transcoding = {
  enabled: ENV.fetch('ERRORDON_TRANSCODING_ENABLED', 'false') == 'true',

  video: {
    variants: {
      default: {
        enabled: true,
        resolution: '1280x720',
        bitrate: '2500k',
        preset: 'medium',
        crf: 23
      },
      mobile: {
        enabled: ENV.fetch('ERRORDON_TRANSCODE_480P', 'true') == 'true',
        resolution: '854x480',
        bitrate: '1000k',
        preset: 'fast',
        crf: 26
      }
    },
    thumbnail: {
      enabled: true,
      resolution: '400x225',
      timestamp: '00:00:01'
    }
  },

  audio: {
    codec: 'aac',
    bitrate: '128k',
    generate_waveform: true
  },

  storage: {
    delete_originals: ENV.fetch('ERRORDON_DELETE_ORIGINALS', 'false') == 'true'
  },

  limits: {
    max_duration: 3600,        # 1 hour max
    job_timeout: 600,          # 10 minutes
    max_queue_size: 100
  }
}

if Rails.application.config.x.errordon_transcoding[:enabled]
  Rails.logger.info '[Errordon] Transcoding pipeline ENABLED'
  Rails.logger.info "[Errordon] Variants: 720p=true, 480p=#{Rails.application.config.x.errordon_transcoding[:video][:variants][:mobile][:enabled]}"
end
