# frozen_string_literal: true

module Errordon
  class NsfwProtectMailer < ApplicationMailer
    layout 'mailer'

    def new_strike(strike)
      @strike = strike
      @account = strike.account
      @config = NsfwProtectConfig.current

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "[NSFW-Protect] New #{strike.strike_type.upcase} violation - #{@account.username}"
      )
    end

    def csam_alert(strike)
      @strike = strike
      @account = strike.account
      @config = NsfwProtectConfig.current

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "[CRITICAL] CSAM DETECTED - IMMEDIATE ACTION REQUIRED",
        importance: 'high'
      )
    end

    def instance_frozen(alarm_count)
      @alarm_count = alarm_count
      @config = NsfwProtectConfig.current

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "[NSFW-Protect] Instance FROZEN - #{alarm_count} active alarms"
      )
    end

    def instance_unfrozen
      @config = NsfwProtectConfig.current

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "[NSFW-Protect] Instance unfrozen - All alarms resolved"
      )
    end

    def user_frozen(account, freeze)
      @account = account
      @freeze = freeze
      @user = account.user

      return unless @user&.email.present?

      I18n.with_locale(@user.locale || I18n.default_locale) do
        mail(
          to: @user.email,
          subject: I18n.t('errordon.nsfw_protect.mailer.user_frozen.subject')
        )
      end
    end
  end
end
