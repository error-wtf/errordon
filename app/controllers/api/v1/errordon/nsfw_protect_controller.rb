# frozen_string_literal: true

class Api::V1::Errordon::NsfwProtectController < Api::BaseController
  before_action :require_user!
  before_action :require_admin!, except: [:status]
  before_action :set_config

  # GET /api/v1/errordon/nsfw_protect/status
  def status
    render json: {
      enabled: @config.enabled?,
      instance_frozen: @config.instance_frozen?,
      user_frozen: current_account_frozen?,
      user_freeze_until: current_account.nsfw_frozen_until,
      user_permanent_freeze: current_account.nsfw_permanent_freeze?,
      user_strike_count: current_account.nsfw_strike_count
    }
  end

  # GET /api/v1/errordon/nsfw_protect/config (admin)
  def config
    render json: {
      enabled: @config.enabled?,
      porn_detection_enabled: @config.porn_detection_enabled?,
      hate_detection_enabled: @config.hate_detection_enabled?,
      illegal_detection_enabled: @config.illegal_detection_enabled?,
      auto_delete_violations: @config.auto_delete_violations?,
      instance_freeze_enabled: @config.instance_freeze_enabled?,
      admin_alert_email: @config.admin_alert_email,
      ollama_endpoint: @config.ollama_endpoint,
      ollama_vision_model: @config.ollama_vision_model,
      ollama_text_model: @config.ollama_text_model,
      instance_alarm_threshold: @config.instance_alarm_threshold,
      instance_frozen: @config.instance_frozen?,
      instance_frozen_at: @config.instance_frozen_at,
      active_alarms: NsfwProtectStrike.unresolved.count
    }
  end

  # PUT /api/v1/errordon/nsfw_protect/config (admin)
  def update_config
    if @config.update(config_params)
      render json: { success: true }
    else
      render json: { error: @config.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/errordon/nsfw_protect/alarms (admin)
  def alarms
    strikes = NsfwProtectStrike.unresolved
                               .includes(:account, :status, :media_attachment)
                               .order(created_at: :desc)
                               .page(params[:page])
                               .per(20)

    render json: {
      alarms: strikes.map { |s| serialize_strike(s) },
      total: strikes.total_count,
      page: strikes.current_page,
      total_pages: strikes.total_pages
    }
  end

  # GET /api/v1/errordon/nsfw_protect/alarms/:id (admin)
  def show_alarm
    strike = NsfwProtectStrike.find(params[:id])
    render json: serialize_strike(strike, detailed: true)
  end

  # POST /api/v1/errordon/nsfw_protect/alarms/:id/resolve (admin)
  def resolve_alarm
    strike = NsfwProtectStrike.find(params[:id])
    strike.resolve!(current_account, notes: params[:notes])

    render json: { success: true, alarm: serialize_strike(strike) }
  end

  # POST /api/v1/errordon/nsfw_protect/alarms/:id/dismiss (admin)
  # Dismiss = false positive, remove strike from account
  def dismiss_alarm
    strike = NsfwProtectStrike.find(params[:id])

    ApplicationRecord.transaction do
      # Decrement strike counts
      strike.account.decrement!(:nsfw_strike_count)
      strike.account.decrement!(:nsfw_porn_strikes) if strike.strike_type_porn?
      strike.account.decrement!(:nsfw_hate_strikes) if strike.strike_type_hate?

      # Deactivate any freeze caused by this strike
      strike.freeze&.deactivate!

      # Mark as resolved
      strike.resolve!(current_account, notes: "Dismissed as false positive: #{params[:notes]}")
    end

    render json: { success: true }
  end

  # GET /api/v1/errordon/nsfw_protect/stats (admin)
  def stats
    render json: {
      total_strikes: NsfwProtectStrike.count,
      unresolved_strikes: NsfwProtectStrike.unresolved.count,
      porn_strikes: NsfwProtectStrike.porn_strikes.count,
      hate_strikes: NsfwProtectStrike.hate_strikes.count,
      frozen_accounts: Account.where('nsfw_frozen_until > ? OR nsfw_permanent_freeze = true', Time.current).count,
      permanent_freezes: Account.where(nsfw_permanent_freeze: true).count,
      strikes_today: NsfwProtectStrike.where(created_at: Time.current.beginning_of_day..).count,
      strikes_this_week: NsfwProtectStrike.where(created_at: 1.week.ago..).count,
      strikes_this_month: NsfwProtectStrike.where(created_at: 30.days.ago..).count,
      unique_violators_this_week: NsfwProtectStrike.where(created_at: 1.week.ago..).distinct.count(:account_id),
      csam_alerts_total: NsfwProtectStrike.where(strike_type: :csam).count,
      instance_frozen: @config.instance_frozen?,
      blocklist: Errordon::DomainBlocklistService.stats
    }
  end

  # GET /api/v1/errordon/nsfw_protect/blocklist (admin)
  def blocklist
    stats = Errordon::DomainBlocklistService.stats
    render json: {
      total_domains: stats[:total_domains],
      hardcoded_count: stats[:hardcoded_count],
      last_updated: stats[:last_updated]&.iso8601,
      sources: stats[:sources],
      file_exists: stats[:file_exists]
    }
  end

  # POST /api/v1/errordon/nsfw_protect/blocklist/update (admin)
  def update_blocklist
    result = Errordon::DomainBlocklistService.update_blocklist!
    
    if result[:success]
      render json: { success: true, count: result[:count] }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/errordon/nsfw_protect/blocklist/check (admin)
  def check_domain
    domain = params[:domain]
    return render json: { error: 'domain parameter required' }, status: :bad_request if domain.blank?

    blocked = Errordon::DomainBlocklistService.blocked?(domain)
    render json: { domain: domain, blocked: blocked }
  end

  # GET /api/v1/errordon/nsfw_protect/report/:strike_id (admin)
  def download_report
    strike = NsfwProtectStrike.find(params[:strike_id])
    report = Errordon::NsfwAuditLogger.generate_law_enforcement_report(strike.id)

    render json: report
  end

  # GET /api/v1/errordon/nsfw_protect/violators (admin)
  def top_violators
    limit = (params[:limit] || 20).to_i.clamp(1, 100)
    
    accounts = Account.where('nsfw_strike_count > 0')
                      .order(nsfw_strike_count: :desc)
                      .limit(limit)
                      .includes(:user)

    render json: {
      violators: accounts.map { |a| serialize_violator(a) }
    }
  end

  # POST /api/v1/errordon/nsfw_protect/send_weekly_summary (admin)
  def send_weekly_summary
    Errordon::WeeklySummaryWorker.perform_async
    render json: { success: true, message: 'Weekly summary queued for delivery' }
  end

  # POST /api/v1/errordon/nsfw_protect/test_ollama (admin)
  def test_ollama
    analyzer = Errordon::OllamaContentAnalyzer.new

    # Test with a simple text prompt
    begin
      uri = URI("#{@config.ollama_endpoint}/api/tags")
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        models = JSON.parse(response.body)['models']&.map { |m| m['name'] } || []
        render json: {
          success: true,
          endpoint: @config.ollama_endpoint,
          available_models: models,
          vision_model_available: models.include?(@config.ollama_vision_model),
          text_model_available: models.include?(@config.ollama_text_model)
        }
      else
        render json: { success: false, error: "Ollama returned #{response.code}" }, status: :service_unavailable
      end
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :service_unavailable
    end
  end

  private

  def set_config
    @config = NsfwProtectConfig.current
  end

  def require_admin!
    forbidden unless current_user&.admin?
  end

  def current_account_frozen?
    return true if current_account.nsfw_permanent_freeze?
    return true if current_account.nsfw_frozen_until.present? && current_account.nsfw_frozen_until > Time.current

    @config.instance_frozen? && current_account.nsfw_ever_frozen?
  end

  def config_params
    params.permit(
      :enabled,
      :porn_detection_enabled,
      :hate_detection_enabled,
      :illegal_detection_enabled,
      :auto_delete_violations,
      :instance_freeze_enabled,
      :admin_alert_email,
      :ollama_endpoint,
      :ollama_vision_model,
      :ollama_text_model,
      :instance_alarm_threshold
    )
  end

  def serialize_strike(strike, detailed: false)
    data = {
      id: strike.id,
      account_id: strike.account_id,
      account_username: strike.account.username,
      account_email: strike.account.user&.email,
      strike_type: strike.strike_type,
      ai_category: strike.ai_category,
      ai_confidence: strike.ai_confidence,
      ai_reason: strike.ai_reason,
      ip_address: strike.ip_address&.to_s,
      resolved: strike.resolved?,
      created_at: strike.created_at.iso8601
    }

    if detailed
      data.merge!(
        status_id: strike.status_id,
        media_attachment_id: strike.media_attachment_id,
        ai_analysis_result: strike.ai_analysis_result,
        resolved_by_id: strike.resolved_by_id,
        resolved_at: strike.resolved_at&.iso8601,
        resolution_notes: strike.resolution_notes,
        account_total_strikes: strike.account.nsfw_strike_count,
        account_frozen: strike.account.nsfw_frozen_until.present? || strike.account.nsfw_permanent_freeze?,
        account_signup_ip: strike.account.user&.sign_up_ip&.to_s,
        account_current_ip: strike.account.user&.current_sign_in_ip&.to_s
      )
    end

    data
  end

  def serialize_violator(account)
    {
      id: account.id,
      username: account.username,
      display_name: account.display_name,
      email: account.user&.email,
      total_strikes: account.nsfw_strike_count,
      porn_strikes: account.nsfw_porn_strikes,
      hate_strikes: account.nsfw_hate_strikes,
      frozen: account.nsfw_frozen_until.present? || account.nsfw_permanent_freeze?,
      permanent_freeze: account.nsfw_permanent_freeze?,
      frozen_until: account.nsfw_frozen_until&.iso8601,
      signup_ip: account.user&.sign_up_ip&.to_s,
      last_ip: account.user&.current_sign_in_ip&.to_s,
      created_at: account.created_at.iso8601
    }
  end
end
