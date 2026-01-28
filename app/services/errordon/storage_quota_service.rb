# frozen_string_literal: true

module Errordon
  # =============================================================================
  # FAIR SHARE STORAGE QUOTA SERVICE
  # =============================================================================
  #
  # This service implements a fair-share storage policy where:
  #
  # 1. GLOBAL CAP (50% default):
  #    - Maximum 50% of disk space can be used for user uploads
  #    - This protects the server from running out of space for system operations
  #    - Configurable via ERRORDON_STORAGE_MAX_PERCENT (default: 50)
  #
  # 2. FAIR SHARE CALCULATION:
  #    - upload_pool_bytes = disk_total * (MAX_PERCENT / 100)
  #    - per_user_quota = upload_pool_bytes / active_users_count
  #    - As more users join, individual quotas decrease proportionally
  #
  # 3. DISK SIZE BASIS:
  #    - Uses TOTAL disk size (not free space) for predictable quotas
  #    - Reasoning: Free space fluctuates with system operations, causing
  #      unpredictable quota changes. Total size is stable.
  #
  # 4. ACTIVE USER DEFINITION (configurable):
  #    - Default: Local accounts, confirmed email, not suspended
  #    - Alternative: Accounts with activity in last N days
  #    - Configurable via ERRORDON_ACTIVE_USER_DEFINITION
  #
  # See docs/STORAGE_FAIR_SHARE.md for full policy documentation.
  # =============================================================================

  class StorageQuotaService
    # Global cap: Maximum percentage of disk for user uploads (default 50%)
    MAX_SYSTEM_USAGE_PERCENT = ENV.fetch('ERRORDON_STORAGE_MAX_PERCENT', 50).to_i

    # Per-user bounds to prevent extreme values
    MIN_QUOTA_PER_USER = ENV.fetch('ERRORDON_STORAGE_MIN_QUOTA_MB', 50).to_i.megabytes
    MAX_QUOTA_PER_USER = ENV.fetch('ERRORDON_STORAGE_MAX_QUOTA_GB', 10).to_i.gigabytes

    # Active user definition: 'confirmed' (default) or 'active_N' (activity in last N days)
    ACTIVE_USER_DEFINITION = ENV.fetch('ERRORDON_ACTIVE_USER_DEFINITION', 'confirmed')

    # Cache TTL for expensive calculations
    CACHE_TTL = 5.minutes

    class << self
      # Returns comprehensive quota information for an account
      # This is the primary method for checking user storage status
      def quota_for(account)
        used = calculate_user_storage(account)
        quota = per_user_quota
        available = [quota - used, 0].max
        percentage = quota.positive? ? (used.to_f / quota * 100).round(1) : 100.0

        {
          # Raw values (bytes)
          quota: quota,
          used: used,
          available: available,
          percentage: percentage,

          # Derived status
          can_upload: available.positive?,
          at_limit: available.zero?,

          # Human-readable strings
          quota_human: human_size(quota),
          used_human: human_size(used),
          available_human: human_size(available),

          # Fair share context (for UI display)
          active_users: active_user_count,
          pool_total: total_available_for_users,
          pool_total_human: human_size(total_available_for_users),
          max_percent: MAX_SYSTEM_USAGE_PERCENT,

          # Explanation for users
          fair_share_notice: fair_share_notice_text(quota, active_user_count)
        }
      end

      # Check if account can upload a file of given size
      def can_upload?(account, file_size = 0)
        return false if file_size.negative?
        return true if exempt_from_quotas?(account)

        info = quota_for(account)
        info[:available] >= file_size
      end

      # Check if account is exempt from quotas (admin/moderator)
      def exempt_from_quotas?(account)
        return false unless account&.user

        exempt_roles = ENV.fetch('ERRORDON_QUOTA_EXEMPT_ROLES', 'Admin,Moderator').split(',')
        exempt_roles.any? { |role| account.user.role&.name == role.strip }
      end

      # Calculate per-user quota based on fair share
      def per_user_quota
        total = total_available_for_users
        count = active_user_count

        return MAX_QUOTA_PER_USER if count.zero?

        raw_quota = (total.to_f / count).to_i
        raw_quota.clamp(MIN_QUOTA_PER_USER, MAX_QUOTA_PER_USER)
      end

      # Total bytes available for user uploads (50% of disk by default)
      def total_available_for_users
        (system_disk_total * MAX_SYSTEM_USAGE_PERCENT / 100.0).to_i
      end

      # Total disk size (cached)
      # Uses TOTAL size, not free space, for predictable quotas
      def system_disk_total
        Rails.cache.fetch('errordon:disk_total', expires_in: CACHE_TTL) do
          begin
            stat = Sys::Filesystem.stat(media_storage_path)
            stat.block_size * stat.blocks
          rescue StandardError => e
            Rails.logger.warn "StorageQuotaService: Could not stat disk: #{e.message}"
            # Fallback: assume 100GB if we can't determine
            100.gigabytes
          end
        end
      end

      # Free disk space (for monitoring)
      def system_disk_free
        Rails.cache.fetch('errordon:disk_free', expires_in: CACHE_TTL) do
          begin
            stat = Sys::Filesystem.stat(media_storage_path)
            stat.block_size * stat.blocks_available
          rescue StandardError
            50.gigabytes
          end
        end
      end

      # Count of active users for fair share calculation
      def active_user_count
        Rails.cache.fetch('errordon:user_count', expires_in: CACHE_TTL) do
          count = case ACTIVE_USER_DEFINITION
                  when /^active_(\d+)$/
                    days = Regexp.last_match(1).to_i
                    Account.local
                           .joins(:user)
                           .where.not(users: { confirmed_at: nil })
                           .where(suspended_at: nil)
                           .where('users.last_sign_in_at > ?', days.days.ago)
                           .count
                  else # 'confirmed' or default
                    Account.local
                           .joins(:user)
                           .where.not(users: { confirmed_at: nil })
                           .where(suspended_at: nil)
                           .count
                  end

          [count, 1].max # Minimum 1 to avoid division by zero
        end
      end

      # Calculate storage used by a specific account
      def calculate_user_storage(account)
        return 0 unless account

        MediaAttachment.where(account_id: account.id).sum(:file_file_size).to_i
      end

      # System-wide statistics for admin dashboards
      def system_stats
        {
          disk_total: system_disk_total,
          disk_free: system_disk_free,
          disk_total_human: human_size(system_disk_total),
          disk_free_human: human_size(system_disk_free),

          upload_pool: total_available_for_users,
          upload_pool_human: human_size(total_available_for_users),
          upload_pool_percent: MAX_SYSTEM_USAGE_PERCENT,

          user_count: active_user_count,
          per_user_quota: per_user_quota,
          per_user_quota_human: human_size(per_user_quota),

          total_used: MediaAttachment.sum(:file_file_size).to_i,
          total_used_human: human_size(MediaAttachment.sum(:file_file_size).to_i),

          min_quota: MIN_QUOTA_PER_USER,
          max_quota: MAX_QUOTA_PER_USER,
          active_user_definition: ACTIVE_USER_DEFINITION
        }
      end

      # Force refresh of cached values
      def refresh!
        Rails.cache.delete('errordon:disk_total')
        Rails.cache.delete('errordon:disk_free')
        Rails.cache.delete('errordon:user_count')
      end

      # Human-readable size formatting
      def human_size(bytes)
        ActiveSupport::NumberHelper.number_to_human_size(bytes)
      end

      private

      # Path to media storage for disk stats
      def media_storage_path
        ENV.fetch('PAPERCLIP_ROOT_PATH', Rails.root.join('public', 'system').to_s)
      end

      # Generate fair share notice text for UI
      def fair_share_notice_text(quota, user_count)
        if user_count > 1
          "Your quota (#{human_size(quota)}) is shared fairly among #{user_count} users. " \
          "As more users join, individual quotas may decrease."
        else
          "You have #{human_size(quota)} of storage available."
        end
      end
    end
  end
end
