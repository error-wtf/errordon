# frozen_string_literal: true

module Errordon
  class BlocklistUpdateWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'default', retry: 3, dead: false

    def perform
      return unless NsfwProtectConfig.current.enabled?

      Rails.logger.info "[NSFW-Protect] Running scheduled blocklist update"
      
      result = Errordon::DomainBlocklistService.update_blocklist!
      
      if result[:success]
        Rails.logger.info "[NSFW-Protect] Blocklist update complete: #{result[:count]} domains"
      else
        Rails.logger.error "[NSFW-Protect] Blocklist update failed: #{result[:error]}"
      end
    end
  end
end
