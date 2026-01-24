# frozen_string_literal: true

# Errordon Scheduled Jobs Configuration
# ======================================
# These jobs run on a schedule via sidekiq-cron or sidekiq-scheduler

Rails.application.config.after_initialize do
  if defined?(Sidekiq) && Sidekiq.server?
    # Only schedule if NSFW-Protect is enabled
    if ENV['ERRORDON_NSFW_PROTECT_ENABLED'] == 'true'
      
      # Check for sidekiq-cron gem
      if defined?(Sidekiq::Cron::Job)
        # Blocklist update - runs daily at 3 AM
        Sidekiq::Cron::Job.create(
          name: 'NSFW-Protect Blocklist Update - daily',
          cron: '0 3 * * *',
          class: 'Errordon::BlocklistUpdateWorker'
        )

        # Freeze cleanup - runs every hour
        Sidekiq::Cron::Job.create(
          name: 'NSFW-Protect Freeze Cleanup - hourly',
          cron: '0 * * * *',
          class: 'Errordon::NsfwFreezeCleanupWorker'
        )

        # Weekly summary - runs every Monday at 9 AM
        Sidekiq::Cron::Job.create(
          name: 'NSFW-Protect Weekly Summary - monday',
          cron: '0 9 * * 1',
          class: 'Errordon::WeeklySummaryWorker'
        )

        # GDPR data retention cleanup - runs daily at 4 AM
        Sidekiq::Cron::Job.create(
          name: 'GDPR Data Retention Cleanup - daily',
          cron: '0 4 * * *',
          class: 'Errordon::GdprCleanupWorker'
        )

        Rails.logger.info "[Errordon] Scheduled jobs configured via sidekiq-cron"
      else
        # Fallback: use recurring jobs via initializer
        Rails.logger.info "[Errordon] sidekiq-cron not available, using manual scheduling"
        
        # Schedule initial blocklist update on startup
        Errordon::BlocklistUpdateWorker.perform_in(1.minute)
      end
    end
  end
end
