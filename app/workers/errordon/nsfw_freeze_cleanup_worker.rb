# frozen_string_literal: true

module Errordon
  class NsfwFreezeCleanupWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'scheduler', retry: 0

    def perform
      # Deactivate expired freezes
      NsfwProtectFreeze.expire_old_freezes!

      # Re-check instance freeze status
      NsfwProtectConfig.check_instance_freeze!

      Rails.logger.info "[NSFW-Protect] Freeze cleanup completed"
    end
  end
end
