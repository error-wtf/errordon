# frozen_string_literal: true

module Errordon
  class NsfwCheckWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'default', retry: 2

    def perform(media_attachment_id, ip_address = nil)
      return unless NsfwProtectConfig.enabled?

      attachment = MediaAttachment.find_by(id: media_attachment_id)
      return if attachment.nil?

      checker = MediaUploadChecker.new(attachment, ip_address: ip_address)
      checker.call
    rescue MediaUploadChecker::ViolationError => e
      Rails.logger.warn "[NSFW-Protect Worker] Violation for media #{media_attachment_id}: #{e.message}"
      # Violation already handled by the checker
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect Worker] Error checking media #{media_attachment_id}: #{e.message}"
      raise e
    end
  end
end
