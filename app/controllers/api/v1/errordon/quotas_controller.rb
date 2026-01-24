# frozen_string_literal: true

class Api::V1::Errordon::QuotasController < Api::BaseController
  before_action :require_staff!, only: [:index, :show, :update]
  before_action :set_account, only: [:show, :update]

  def index
    @accounts = Account.joins(:user)
                       .joins(:media_attachments)
                       .group('accounts.id')
                       .select('accounts.*, SUM(media_attachments.file_file_size) as total_storage')
                       .having('SUM(media_attachments.file_file_size) > 0')
                       .order('total_storage DESC')
                       .limit(100)

    render json: {
      stats: global_stats,
      users: @accounts.map { |a| user_quota_data(a) }
    }
  end

  def show
    quota_service = Errordon::QuotaService.new(@account)
    render json: quota_service.quota_stats
  end

  def current
    quota_service = Errordon::QuotaService.new(current_account)
    render json: quota_service.quota_stats
  end

  def update
    # Update user's quota (admin only)
    new_quota = params[:quota].to_i

    if new_quota.positive?
      # Store custom quota in user settings (JSON field)
      @account.user.settings['errordon_custom_quota'] = new_quota
      @account.user.save!
      
      Errordon::AuditLogger.log_admin_action(
        :quota_updated,
        current_account,
        @account,
        { new_quota: new_quota }
      )
      
      render json: { success: true, new_quota: new_quota }
    else
      render json: { error: 'Invalid quota value' }, status: :unprocessable_entity
    end
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def global_stats
    config = Rails.application.config.x.errordon_quotas

    {
      total_storage_used: MediaAttachment.sum(:file_file_size),
      active_uploaders: Account.joins(:media_attachments)
                               .where('media_attachments.created_at > ?', 30.days.ago)
                               .distinct
                               .count,
      pending_transcodes: MediaAttachment.where(processing_status: 'pending').count,
      failed_transcodes: MediaAttachment.where(processing_status: 'failed').count,
      quotas_enabled: config[:enabled],
      default_quota: config.dig(:storage, :max_per_user)
    }
  end

  def user_quota_data(account)
    quota_service = Errordon::QuotaService.new(account)
    stats = quota_service.quota_stats

    {
      id: account.id,
      username: account.username,
      display_name: account.display_name,
      storage_used: stats[:storage][:used],
      storage_quota: stats[:storage][:quota],
      usage_percent: stats[:storage][:percent],
      uploads_today: stats[:daily][:uploads_count],
      exempt: stats[:exempt]
    }
  end
end
