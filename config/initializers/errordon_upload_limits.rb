# frozen_string_literal: true

# Errordon Upload Limits Configuration
# Increases default Mastodon limits for video/audio uploads
#
# ENV variables:
#   MAX_VIDEO_SIZE - Maximum video file size (default: 250MB)
#   MAX_AUDIO_SIZE - Maximum audio file size (default: 250MB)
#   MAX_IMAGE_SIZE - Maximum image file size (default: 16MB)

Rails.application.config.x.errordon_upload_limits = {
  video: ENV.fetch('MAX_VIDEO_SIZE', 262_144_000).to_i,  # 250MB
  audio: ENV.fetch('MAX_AUDIO_SIZE', 262_144_000).to_i,  # 250MB
  image: ENV.fetch('MAX_IMAGE_SIZE', 16_777_216).to_i    # 16MB
}

# Override Mastodon's default MediaAttachment limits if ENV is set
if ENV['ERRORDON_UPLOAD_LIMITS'] == 'true'
  Rails.application.config.to_prepare do
    MediaAttachment.class_eval do
      # Override size limits
      remove_const(:IMAGE_FILE_SIZE_LIMIT) if const_defined?(:IMAGE_FILE_SIZE_LIMIT)
      remove_const(:VIDEO_FILE_SIZE_LIMIT) if const_defined?(:VIDEO_FILE_SIZE_LIMIT)

      const_set(:IMAGE_FILE_SIZE_LIMIT, Rails.application.config.x.errordon_upload_limits[:image])
      const_set(:VIDEO_FILE_SIZE_LIMIT, Rails.application.config.x.errordon_upload_limits[:video])

      Rails.logger.info "[Errordon] Upload limits: Video=#{VIDEO_FILE_SIZE_LIMIT / 1.megabyte}MB, Image=#{IMAGE_FILE_SIZE_LIMIT / 1.megabyte}MB"
    end
  end
end
