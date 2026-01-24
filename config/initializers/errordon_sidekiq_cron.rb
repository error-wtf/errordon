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

        # Snapshot cleanup - runs daily at 4:30 AM (delete safe snapshots after 14 days)
        Sidekiq::Cron::Job.create(
          name: 'AI Snapshot Cleanup (14 days) - daily',
          cron: '30 4 * * *',
          class: 'Errordon::SnapshotCleanupWorker'
        )

        Rails.logger.info "[Errordon] NSFW-Protect scheduled jobs configured"
      else
        # Fallback: use recurring jobs via initializer
        Rails.logger.info "[Errordon] sidekiq-cron not available, using manual scheduling"
        Errordon::BlocklistUpdateWorker.perform_in(1.minute)
      end
    end

    # Video cleanup - runs daily at 5 AM (independent of NSFW-Protect)
    if ENV['ERRORDON_VIDEO_CLEANUP_ENABLED'] == 'true' && defined?(Sidekiq::Cron::Job)
      Sidekiq::Cron::Job.create(
        name: 'Video Cleanup (480p shrink) - daily',
        cron: '0 5 * * *',
        class: 'Errordon::VideoCleanupWorker'
      )
      Rails.logger.info "[Errordon] Video cleanup job scheduled (daily 5 AM)"
    end
  end
end
