# frozen_string_literal: true

module Errordon
  class VideoCleanupWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'pull', retry: 1, lock: :until_executed

    def perform(dry_run = false)
      return unless VideoCleanupService.enabled?

      Rails.logger.info "[Errordon VideoCleanup] Starting scheduled cleanup (dry_run=#{dry_run})"

      stats = VideoCleanupService.run!(dry_run: dry_run)

      Rails.logger.info "[Errordon VideoCleanup] Finished: #{stats.to_json}"
    rescue StandardError => e
      Rails.logger.error "[Errordon VideoCleanup] Worker failed: #{e.message}"
      raise e
    end
  end
end
