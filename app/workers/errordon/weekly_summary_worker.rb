# frozen_string_literal: true

module Errordon
  class WeeklySummaryWorker
    include Sidekiq::Worker

    sidekiq_options queue: 'mailers', retry: 3

    def perform
      return unless NsfwProtectConfig.current.enabled?
      return unless NsfwProtectConfig.current.admin_alert_email.present?

      Rails.logger.info "[NSFW-Protect] Sending weekly summary email"
      
      Errordon::NsfwProtectMailer.weekly_summary.deliver_now
      
      Rails.logger.info "[NSFW-Protect] Weekly summary sent successfully"
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect] Weekly summary failed: #{e.message}"
      raise e
    end
  end
end
