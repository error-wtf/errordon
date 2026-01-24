# frozen_string_literal: true

module Errordon
  class NsfwProtectMailer < ApplicationMailer
    layout 'mailer'
    helper :accounts

    def new_strike(strike)
      @strike = strike
      @account = strike.account
      @user = @account.user
      @config = NsfwProtectConfig.current
      @domain = Rails.configuration.x.local_domain

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "[NSFW-Protect] #{strike.strike_type.upcase} violation - @#{@account.username} [Strike ##{strike.id}]"
      )
    end

    def csam_alert(strike)
      @strike = strike
      @account = strike.account
      @user = @account.user
      @config = NsfwProtectConfig.current
      @domain = Rails.configuration.x.local_domain

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "🚨 [CRITICAL] CSAM DETECTED - @#{@account.username} - IMMEDIATE ACTION REQUIRED",
        importance: 'high',
        'X-Priority': '1'
      )
    end

    def instance_frozen(alarm_count)
      @alarm_count = alarm_count
      @config = NsfwProtectConfig.current
      @active_strikes = NsfwProtectStrike.unresolved.includes(:account).limit(20)

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "⚠️ [NSFW-Protect] Instance FROZEN - #{alarm_count} active alarms",
        importance: 'high'
      )
    end

    def instance_unfrozen
      @config = NsfwProtectConfig.current

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "✅ [NSFW-Protect] Instance unfrozen - All alarms resolved"
      )
    end

    def user_frozen(account, freeze)
      @account = account
      @freeze = freeze
      @user = account.user
      @domain = Rails.configuration.x.local_domain

      return unless @user&.email.present?

      I18n.with_locale(@user.locale || I18n.default_locale) do
        mail(
          to: @user.email,
          subject: I18n.t('errordon.nsfw_protect.mailer.user_frozen.subject')
        )
      end
    end

    def weekly_summary
      @config = NsfwProtectConfig.current
      @domain = Rails.configuration.x.local_domain
      @period_start = 1.week.ago.beginning_of_day
      @period_end = Time.current

      @stats = Errordon::NsfwAuditLogger.violation_summary(days: 7)
      @recent_strikes = NsfwProtectStrike.where(created_at: @period_start..).includes(:account).order(created_at: :desc).limit(50)
      @top_violators = Account.where(id: @recent_strikes.map(&:account_id)).order(nsfw_strike_count: :desc).limit(10)
      @blocklist_stats = Errordon::DomainBlocklistService.stats

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "📊 [NSFW-Protect] Weekly Summary - #{@period_start.strftime('%Y-%m-%d')} to #{@period_end.strftime('%Y-%m-%d')}"
      )
    end
  end
end
