# frozen_string_literal: true

module Errordon
  class QuotaService
    class QuotaExceededError < StandardError; end
    class RateLimitExceededError < StandardError; end

    def initialize(account)
      @account = account
      @config = Rails.application.config.x.errordon_quotas
    end

    def check_upload_allowed!(file_size)
      return true unless @config[:enabled]
      return true if exempt_from_quotas?

      check_storage_quota!(file_size)
      check_daily_limit!(file_size)
      check_rate_limit!

      true
    end

    def storage_used
      @account.media_attachments.sum(:file_file_size)
    end

    def storage_quota
      @config.dig(:storage, :max_per_user) || 10.gigabytes
    end

    def storage_usage_percent
      return 0 if storage_quota.zero?

      ((storage_used.to_f / storage_quota) * 100).round(1)
    end

    def daily_upload_size
      @account.media_attachments
              .where('created_at > ?', 24.hours.ago)
              .sum(:file_file_size)
    end

    def daily_upload_limit
      @config.dig(:rate_limits, :upload_size_per_day) || 2.gigabytes
    end

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

    def quota_stats
      {
        storage: {
          used: storage_used,
          quota: storage_quota,
          percent: storage_usage_percent
        },
        daily: {
          uploaded: daily_upload_size,
          limit: daily_upload_limit,
          uploads_count: uploads_today
        },
        hourly: {
          uploads: uploads_this_hour,
          limit: uploads_per_hour_limit
        },
        exempt: exempt_from_quotas?
      }
    end

    private

    def check_storage_quota!(file_size)
      if storage_used + file_size > storage_quota
        raise QuotaExceededError, "Storage quota exceeded. Used: #{helpers.number_to_human_size(storage_used)}, Quota: #{helpers.number_to_human_size(storage_quota)}"
      end
    end

    def check_daily_limit!(file_size)
      if daily_upload_size + file_size > daily_upload_limit
        raise QuotaExceededError, "Daily upload limit exceeded. Uploaded: #{helpers.number_to_human_size(daily_upload_size)}, Limit: #{helpers.number_to_human_size(daily_upload_limit)}"
      end
    end

    def check_rate_limit!
      if uploads_this_hour >= uploads_per_hour_limit
        raise RateLimitExceededError, "Rate limit exceeded. #{uploads_this_hour} uploads this hour, limit is #{uploads_per_hour_limit}"
      end
    end

    def exempt_from_quotas?
      return false unless @account.user

      exempt_roles = @config[:exempt_roles] || %w[Admin Moderator]
      exempt_roles.any? { |role| @account.user.role&.name == role }
    end

    def helpers
      ActionController::Base.helpers
    end
  end
end
