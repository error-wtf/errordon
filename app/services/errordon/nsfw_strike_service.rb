# frozen_string_literal: true

module Errordon
  class NsfwStrikeService
    def initialize(strike)
      @strike = strike
      @account = strike.account
      @config = NsfwProtectConfig.current
    end

    def call
      return unless @config.enabled?
      
      # Admins/Moderatoren sind ausgenommen (für Testing)
      if admin_account?
        Rails.logger.info "[NSFW-Protect] Admin/Moderator bypass: Strike #{@strike.id} nicht angewendet für @#{@account.username}"
        @strike.update!(resolution_notes: 'Admin/Moderator bypass - nicht angewendet')
        return
      end

      # Update account strike counts
      update_strike_counts!

      # Delete violating content if configured
      delete_violation_content! if @config.auto_delete_violations?

      # Apply freeze based on strike type and count
      apply_freeze!

      # Log the action
      log_strike_action!

      # Special handling for CSAM - immediate permanent ban
      handle_csam! if @strike.strike_type_csam?
    end

    private

    def update_strike_counts!
      @account.increment!(:nsfw_strike_count)

      case @strike.strike_type
      when 'porn'
        @account.increment!(:nsfw_porn_strikes)
      when 'hate'
        @account.increment!(:nsfw_hate_strikes)
      end

      @account.update!(nsfw_last_strike_ip: @strike.ip_address) if @strike.ip_address.present?
    end

    def delete_violation_content!
      # Delete the specific status if linked
      if @strike.status.present?
        @strike.status.discard! unless @strike.status.discarded?
        Rails.logger.info "[NSFW-Protect] Deleted status #{@strike.status_id} for account #{@account.id}"
      end

      # Also delete the media attachment
      if @strike.media_attachment.present?
        @strike.media_attachment.destroy
        Rails.logger.info "[NSFW-Protect] Deleted media #{@strike.media_attachment_id} for account #{@account.id}"
      end
    end

    def apply_freeze!
      freeze_params = calculate_freeze_params

      return if freeze_params.nil? # No freeze for warnings

      NsfwProtectFreeze.create!(
        account: @account,
        nsfw_protect_strike: @strike,
        freeze_type: freeze_params[:type],
        duration_hours: freeze_params[:duration] || 8760, # Default 1 year for permanent
        started_at: Time.current,
        permanent: freeze_params[:permanent],
        ip_address: @strike.ip_address
      )
    end

    def calculate_freeze_params
      case @strike.strike_type
      when 'porn'
        calculate_porn_freeze
      when 'hate'
        calculate_hate_freeze
      when 'illegal'
        calculate_illegal_freeze
      when 'csam'
        { type: :csam_violation, duration: 87600, permanent: true } # Permanent
      else
        nil
      end
    end

    def calculate_porn_freeze
      strike_count = @account.nsfw_porn_strikes

      duration = NsfwProtectFreeze.duration_for_porn_strike(strike_count)

      if duration.nil? # 5th+ strike = permanent
        { type: :porn_violation, duration: 87600, permanent: true }
      else
        { type: :porn_violation, duration: duration, permanent: false }
      end
    end

    def calculate_hate_freeze
      strike_count = @account.nsfw_hate_strikes

      duration = NsfwProtectFreeze.duration_for_hate_strike(strike_count)

      if duration.nil? # 4th+ strike = permanent
        { type: :hate_violation, duration: 87600, permanent: true }
      else
        { type: :hate_violation, duration: duration, permanent: false }
      end
    end

    def calculate_illegal_freeze
      # Illegal content gets progressively longer freezes
      strike_count = @account.nsfw_strike_count

      case strike_count
      when 1
        { type: :illegal_violation, duration: 168, permanent: false } # 7 days
      when 2
        { type: :illegal_violation, duration: 720, permanent: false } # 30 days
      else
        { type: :illegal_violation, duration: 87600, permanent: true } # Permanent
      end
    end

    def handle_csam!
      # CSAM requires immediate action and potential law enforcement notification
      Rails.logger.error "[NSFW-Protect] CSAM DETECTED! Account: #{@account.id}, IP: #{@strike.ip_address}"

      # Permanent freeze
      @account.update!(nsfw_permanent_freeze: true)

      # Suspend account completely
      @account.suspend!(origin: :local)

      # Notify admin immediately
      if @config.admin_alert_email.present?
        Errordon::NsfwProtectMailer.csam_alert(@strike).deliver_now
      end

      # Log for potential law enforcement
      AuditLogger.log(
        action: 'csam_detected',
        account_id: @account.id,
        ip_address: @strike.ip_address&.to_s,
        media_id: @strike.media_attachment_id,
        status_id: @strike.status_id,
        timestamp: Time.current.iso8601
      )
    end

    def log_strike_action!
      Rails.logger.info "[NSFW-Protect] Strike applied: Account=#{@account.id}, Type=#{@strike.strike_type}, " \
                        "Confidence=#{@strike.ai_confidence}, TotalStrikes=#{@account.nsfw_strike_count}, " \
                        "IP=#{@strike.ip_address}"

      # Use enhanced audit logger for comprehensive violation logging
      Errordon::NsfwAuditLogger.log_violation(
        strike: @strike,
        account: @account,
        request_info: {
          ip: @strike.ip_address&.to_s,
          user_agent: nil,
          referrer: nil
        }
      )
    end

    def admin_account?
      return false unless @account.present?
      
      user = @account.user
      return false unless user.present?
      
      user.admin? || user.moderator?
    end
  end
end
