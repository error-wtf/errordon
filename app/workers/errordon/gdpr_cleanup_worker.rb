# frozen_string_literal: true

module Errordon
  class GdprCleanupWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'default', retry: 3

    # Läuft täglich um 4:00 Uhr
    # Bereinigt abgelaufene Daten gemäß DSGVO Aufbewahrungsfristen
    def perform
      Rails.logger.info "[GDPR] Starting scheduled data retention cleanup"
      
      result = Errordon::GdprComplianceService.cleanup_expired_data!
      
      if result[:actions].any?
        Rails.logger.info "[GDPR] Cleanup complete: #{result[:actions].size} actions performed"
      else
        Rails.logger.info "[GDPR] Cleanup complete: No data to clean up"
      end
    rescue StandardError => e
      Rails.logger.error "[GDPR] Cleanup failed: #{e.message}"
      raise e
    end
  end
end
