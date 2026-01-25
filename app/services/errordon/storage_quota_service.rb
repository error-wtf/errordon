# frozen_string_literal: true

module Errordon
  class StorageQuotaService
    MAX_SYSTEM_USAGE_PERCENT = ENV.fetch('ERRORDON_STORAGE_MAX_PERCENT', 60).to_i
    MIN_QUOTA_PER_USER = ENV.fetch('ERRORDON_STORAGE_MIN_QUOTA_MB', 50).to_i.megabytes
    MAX_QUOTA_PER_USER = ENV.fetch('ERRORDON_STORAGE_MAX_QUOTA_GB', 50).to_i.gigabytes
    CACHE_TTL = 5.minutes

    class << self
      def quota_for(account)
        used = calculate_user_storage(account)
        quota = per_user_quota
        available = [quota - used, 0].max
        percentage = quota.positive? ? (used.to_f / quota * 100).round(1) : 0

        {
          quota: quota, used: used, available: available, percentage: percentage,
          can_upload: used < quota,
          quota_human: human_size(quota), used_human: human_size(used),
          available_human: human_size(available)
        }
      end

      def can_upload?(account, file_size = 0)
        info = quota_for(account)
        info[:available] >= file_size
      end

      def per_user_quota
        total = total_available_for_users
        count = active_user_count
        return MAX_QUOTA_PER_USER if count.zero?
        (total / count).clamp(MIN_QUOTA_PER_USER, MAX_QUOTA_PER_USER)
      end

      def total_available_for_users
        (system_disk_total * MAX_SYSTEM_USAGE_PERCENT / 100.0).to_i
      end

      def system_disk_total
        Rails.cache.fetch('errordon:disk_total', expires_in: CACHE_TTL) do
          begin
            stat = Sys::Filesystem.stat(media_storage_path)
            stat.block_size * stat.blocks
          rescue
            100.gigabytes
          end
        end
      end

      def active_user_count
        Rails.cache.fetch('errordon:user_count', expires_in: CACHE_TTL) do
          [Account.local.joins(:user).where.not(users: { confirmed_at: nil })
                  .where(suspended_at: nil).count, 1].max
        end
      end

      def calculate_user_storage(account)
        return 0 unless account
        MediaAttachment.where(account_id: account.id).sum(:file_file_size).to_i
      end

      def system_stats
        { system_total: system_disk_total, user_count: active_user_count,
          per_user_quota: per_user_quota, max_percent: MAX_SYSTEM_USAGE_PERCENT }
      end

      def refresh!
        Rails.cache.delete('errordon:disk_total')
        Rails.cache.delete('errordon:user_count')
      end

      def human_size(bytes)
        ActiveSupport::NumberHelper.number_to_human_size(bytes)
      end

      private

      def media_storage_path
        ENV.fetch('PAPERCLIP_ROOT_PATH', Rails.root.join('public', 'system').to_s)
      end
    end
  end
end
