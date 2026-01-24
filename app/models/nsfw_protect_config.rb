# frozen_string_literal: true

# == Schema Information
#
# Table name: nsfw_protect_configs
#
#  id                        :bigint(8)        not null, primary key
#  enabled                   :boolean          default(FALSE), not null
#  porn_detection_enabled    :boolean          default(TRUE), not null
#  hate_detection_enabled    :boolean          default(TRUE), not null
#  illegal_detection_enabled :boolean          default(TRUE), not null
#  auto_delete_violations    :boolean          default(TRUE), not null
#  instance_freeze_enabled   :boolean          default(TRUE), not null
#  admin_alert_email         :string
#  ollama_endpoint           :string           default("http://localhost:11434")
#  ollama_vision_model       :string           default("llava")
#  ollama_text_model         :string           default("llama3")
#  instance_alarm_threshold  :integer          default(10), not null
#  instance_frozen           :boolean          default(FALSE), not null
#  instance_frozen_at        :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#

class NsfwProtectConfig < ApplicationRecord
  validates :instance_alarm_threshold, numericality: { greater_than: 0 }
  validates :ollama_endpoint, presence: true, if: :enabled?
  validates :admin_alert_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  class << self
    def current
      first_or_create!
    end

    def enabled?
      current.enabled?
    end

    def porn_detection?
      enabled? && current.porn_detection_enabled?
    end

    def hate_detection?
      enabled? && current.hate_detection_enabled?
    end

    def illegal_detection?
      enabled? && current.illegal_detection_enabled?
    end

    def instance_frozen?
      current.instance_frozen?
    end

    def active_alarm_count
      NsfwProtectStrike.unresolved.count
    end

    def check_instance_freeze!
      config = current
      return unless config.instance_freeze_enabled?

      alarm_count = active_alarm_count

      if alarm_count >= config.instance_alarm_threshold && !config.instance_frozen?
        config.update!(instance_frozen: true, instance_frozen_at: Time.current)
        Errordon::NsfwProtectMailer.instance_frozen(alarm_count).deliver_later if config.admin_alert_email.present?
      elsif alarm_count < config.instance_alarm_threshold && config.instance_frozen?
        config.update!(instance_frozen: false, instance_frozen_at: nil)
        Errordon::NsfwProtectMailer.instance_unfrozen.deliver_later if config.admin_alert_email.present?
      end
    end
  end

  def ollama_configured?
    ollama_endpoint.present? && ollama_vision_model.present?
  end
end
