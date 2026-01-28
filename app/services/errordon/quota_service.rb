# frozen_string_literal: true

module Errordon
  # =============================================================================
  # QUOTA SERVICE - Upload Enforcement and Rate Limiting
  # =============================================================================
  #
  # This service enforces upload quotas and rate limits for individual accounts.
  # It integrates with StorageQuotaService for fair-share storage calculations.
  #
  # Features:
  # - Storage quota enforcement (fair share based)
  # - Daily upload size limits
  # - Hourly upload count limits (rate limiting)
  # - Admin/Moderator exemptions
  #
  # When quota is exceeded:
  # - Media uploads are blocked
  # - Text-only posts (with links) are still allowed
  # - User must delete existing uploads to free space
  #
  # See docs/STORAGE_FAIR_SHARE.md for full policy documentation.
  # =============================================================================

  class QuotaService
    class QuotaExceededError < StandardError
      attr_reader :details

      def initialize(message, details = {})
        @details = details
        super(message)
      end
    end

    class RateLimitExceededError < StandardError
      attr_reader :details

      def initialize(message, details = {})
        @details = details
        super(message)
      end
    end

    def initialize(account)
      @account = account
      @config = Rails.application.config.x.errordon_quotas || {}
    end

    # Main entry point: Check if upload is allowed
    # Raises QuotaExceededError or RateLimitExceededError if not
    def check_upload_allowed!(file_size)
      return true unless quotas_enabled?
      return true if exempt_from_quotas?

      check_storage_quota!(file_size)
      check_daily_limit!(file_size)
      check_rate_limit!

      true
    end

    # Check if ANY upload is possible (for UI)
    def can_upload?
      return true unless quotas_enabled?
      return true if exempt_from_quotas?

      storage_available.positive?
    end

    # Check if upload of specific size is possible
    def can_upload_size?(file_size)
      return true unless quotas_enabled?
      return true if exempt_from_quotas?

      storage_available >= file_size
    end

    # =========================================================================
    # STORAGE QUOTA (Fair Share)
    # =========================================================================

    # Uses StorageQuotaService for fair share calculation
    def storage_quota
      StorageQuotaService.per_user_quota
    end

    def storage_used
      StorageQuotaService.calculate_user_storage(@account)
    end

    def storage_available
      [storage_quota - storage_used, 0].max
    end

    def storage_usage_percent
      return 0 if storage_quota.zero?
      ((storage_used.to_f / storage_quota) * 100).round(1)
    end

    def at_storage_limit?
      storage_available.zero?
    end

    # =========================================================================
    # DAILY LIMITS
    # =========================================================================

    def daily_upload_size
      @account.media_attachments
              .where('created_at > ?', 24.hours.ago)
              .sum(:file_file_size)
    end

    def daily_upload_limit
      @config.dig(:rate_limits, :upload_size_per_day) || 1.gigabyte
    end

    def daily_remaining
      [daily_upload_limit - daily_upload_size, 0].max
    end

    # =========================================================================
    # HOURLY RATE LIMITS
    # =========================================================================

    def uploads_today
      @account.media_attachments
              .where('created_at > ?', 24.hours.ago)
              .count
    end

    def uploads_per_hour_limit
      @config.dig(:rate_limits, :uploads_per_hour) || 20
    end

    def uploads_this_hour
      @account.media_attachments
              .where('created_at > ?', 1.hour.ago)
              .count
    end

    # =========================================================================
    # COMPREHENSIVE STATS (for API/UI)
    # =========================================================================

    def quota_stats
      fair_share_info = StorageQuotaService.quota_for(@account)

      {
        # Storage (fair share)
        storage: {
          used: storage_used,
          used_human: helpers.number_to_human_size(storage_used),
          quota: storage_quota,
          quota_human: helpers.number_to_human_size(storage_quota),
          available: storage_available,
          available_human: helpers.number_to_human_size(storage_available),
          percent: storage_usage_percent,
          at_limit: at_storage_limit?,
          can_upload: can_upload?
        },

        # Daily limits
        daily: {
          uploaded: daily_upload_size,
          uploaded_human: helpers.number_to_human_size(daily_upload_size),
          limit: daily_upload_limit,
          limit_human: helpers.number_to_human_size(daily_upload_limit),
          remaining: daily_remaining,
          remaining_human: helpers.number_to_human_size(daily_remaining),
          uploads_count: uploads_today
        },

        # Hourly rate limits
        hourly: {
          uploads: uploads_this_hour,
          limit: uploads_per_hour_limit,
          remaining: [uploads_per_hour_limit - uploads_this_hour, 0].max
        },

        # Fair share context
        fair_share: {
          active_users: fair_share_info[:active_users],
          pool_total: fair_share_info[:pool_total],
          pool_total_human: fair_share_info[:pool_total_human],
          max_percent: fair_share_info[:max_percent],
          notice: fair_share_info[:fair_share_notice]
        },

        # Status flags
        exempt: exempt_from_quotas?,
        quotas_enabled: quotas_enabled?,

        # Upload limits (fediverse-compatible)
        upload_limits: {
          image: MediaAttachment::IMAGE_LIMIT,
          image_human: helpers.number_to_human_size(MediaAttachment::IMAGE_LIMIT),
          video: MediaAttachment::VIDEO_LIMIT,
          video_human: helpers.number_to_human_size(MediaAttachment::VIDEO_LIMIT)
        }
      }
    end

    # Simple status for quick checks
    def status
      {
        can_upload: can_upload?,
        at_limit: at_storage_limit?,
        used_percent: storage_usage_percent,
        available: storage_available,
        available_human: helpers.number_to_human_size(storage_available)
      }
    end

    private

    def quotas_enabled?
      @config[:enabled] != false
    end

    def check_storage_quota!(file_size)
      if storage_used + file_size > storage_quota
        raise QuotaExceededError.new(
          I18n.t('errordon.quota.storage_exceeded',
                 used: helpers.number_to_human_size(storage_used),
                 quota: helpers.number_to_human_size(storage_quota)),
          {
            type: :storage,
            used: storage_used,
            quota: storage_quota,
            requested: file_size
          }
        )
      end
    end

    def check_daily_limit!(file_size)
      if daily_upload_size + file_size > daily_upload_limit
        raise QuotaExceededError.new(
          I18n.t('errordon.quota.daily_exceeded',
                 uploaded: helpers.number_to_human_size(daily_upload_size),
                 limit: helpers.number_to_human_size(daily_upload_limit)),
          {
            type: :daily,
            uploaded: daily_upload_size,
            limit: daily_upload_limit,
            requested: file_size
          }
        )
      end
    end

    def check_rate_limit!
      if uploads_this_hour >= uploads_per_hour_limit
        raise RateLimitExceededError.new(
          I18n.t('errordon.quota.rate_exceeded',
                 count: uploads_this_hour,
                 limit: uploads_per_hour_limit),
          {
            type: :rate,
            uploads: uploads_this_hour,
            limit: uploads_per_hour_limit
          }
        )
      end
    end

    def exempt_from_quotas?
      StorageQuotaService.exempt_from_quotas?(@account)
    end

    def helpers
      ActionController::Base.helpers
    end
  end
end
