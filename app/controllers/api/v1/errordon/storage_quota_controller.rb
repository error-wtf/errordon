# frozen_string_literal: true

class Api::V1::Errordon::StorageQuotaController < Api::BaseController
  before_action :require_user!

  # GET /api/v1/errordon/storage_quota
  # Returns comprehensive storage quota information for the current user
  #
  # Response includes:
  # - Current storage usage and quota
  # - Fair share information (active users, pool size)
  # - Daily and hourly limits
  # - Upload limits (fediverse-compatible)
  # - Status flags (can_upload, at_limit)
  #
  def show
    quota_service = Errordon::QuotaService.new(current_account)
    stats = quota_service.quota_stats

    render json: {
      # Storage status
      storage: {
        used: stats[:storage][:used],
        used_human: stats[:storage][:used_human],
        quota: stats[:storage][:quota],
        quota_human: stats[:storage][:quota_human],
        available: stats[:storage][:available],
        available_human: stats[:storage][:available_human],
        percent: stats[:storage][:percent],
        at_limit: stats[:storage][:at_limit],
        can_upload: stats[:storage][:can_upload]
      },

      # Fair share context (important for UX)
      fair_share: {
        active_users: stats[:fair_share][:active_users],
        pool_total: stats[:fair_share][:pool_total],
        pool_total_human: stats[:fair_share][:pool_total_human],
        max_percent: stats[:fair_share][:max_percent],
        notice: stats[:fair_share][:notice]
      },

      # Daily limits
      daily: {
        uploaded: stats[:daily][:uploaded],
        uploaded_human: stats[:daily][:uploaded_human],
        limit: stats[:daily][:limit],
        limit_human: stats[:daily][:limit_human],
        remaining: stats[:daily][:remaining],
        remaining_human: stats[:daily][:remaining_human],
        uploads_count: stats[:daily][:uploads_count]
      },

      # Hourly rate limits
      hourly: {
        uploads: stats[:hourly][:uploads],
        limit: stats[:hourly][:limit],
        remaining: stats[:hourly][:remaining]
      },

      # Upload limits (fediverse-compatible)
      upload_limits: stats[:upload_limits],

      # Status flags
      can_upload: stats[:storage][:can_upload],
      at_limit: stats[:storage][:at_limit],
      exempt: stats[:exempt],
      quotas_enabled: stats[:quotas_enabled]
    }
  end

  # GET /api/v1/errordon/storage_quota/status
  # Quick status check for upload buttons/forms
  #
  def status
    quota_service = Errordon::QuotaService.new(current_account)
    status = quota_service.status

    render json: {
      can_upload: status[:can_upload],
      at_limit: status[:at_limit],
      used_percent: status[:used_percent],
      available: status[:available],
      available_human: status[:available_human]
    }
  end
end
