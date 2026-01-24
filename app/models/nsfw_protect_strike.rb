# frozen_string_literal: true

# == Schema Information
#
# Table name: nsfw_protect_strikes
#
#  id                  :bigint(8)        not null, primary key
#  account_id          :bigint(8)        not null
#  status_id           :bigint(8)
#  media_attachment_id :bigint(8)
#  report_id           :bigint(8)
#  strike_type         :integer          default(0), not null
#  severity            :integer          default(1), not null
#  ip_address          :inet
#  ai_analysis_result  :text
#  ai_confidence       :float
#  ai_category         :string
#  ai_reason           :text
#  resolved            :boolean          default(FALSE), not null
#  resolved_by_id      :bigint(8)
#  resolved_at         :datetime
#  resolution_notes    :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class NsfwProtectStrike < ApplicationRecord
  belongs_to :account
  belongs_to :status, optional: true
  belongs_to :media_attachment, optional: true
  belongs_to :report, optional: true
  belongs_to :resolved_by, class_name: 'Account', optional: true

  has_one :freeze, class_name: 'NsfwProtectFreeze', dependent: :nullify

  enum :strike_type, {
    porn: 0,
    hate: 1,
    illegal: 2,
    csam: 3,  # Child Sexual Abuse Material - immediate permanent ban + authorities
    other: 99
  }, prefix: true

  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :porn_strikes, -> { where(strike_type: :porn) }
  scope :hate_strikes, -> { where(strike_type: :hate) }
  scope :recent, -> { where(created_at: 30.days.ago..) }
  scope :by_account, ->(account) { where(account: account) }

  validates :strike_type, presence: true
  validates :ai_confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

  after_create :apply_consequences!
  after_create :notify_admins!
  after_create :check_instance_freeze!

  def resolve!(admin_account, notes: nil)
    update!(
      resolved: true,
      resolved_by: admin_account,
      resolved_at: Time.current,
      resolution_notes: notes
    )
    NsfwProtectConfig.check_instance_freeze!
  end

  def high_confidence?
    ai_confidence.present? && ai_confidence >= 0.85
  end

  def requires_immediate_action?
    strike_type_csam? || (strike_type_porn? && high_confidence?)
  end

  private

  def apply_consequences!
    Errordon::NsfwStrikeService.new(self).call
  end

  def notify_admins!
    return unless NsfwProtectConfig.current.admin_alert_email.present?

    Errordon::NsfwProtectMailer.new_strike(self).deliver_later
  end

  def check_instance_freeze!
    NsfwProtectConfig.check_instance_freeze!
  end
end
