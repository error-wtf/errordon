# frozen_string_literal: true

# == Schema Information
#
# Table name: nsfw_protect_freezes
#
#  id                     :bigint(8)        not null, primary key
#  account_id             :bigint(8)        not null
#  nsfw_protect_strike_id :bigint(8)
#  freeze_type            :integer          default(0), not null
#  duration_hours         :integer          not null
#  started_at             :datetime         not null
#  ends_at                :datetime
#  permanent              :boolean          default(FALSE), not null
#  active                 :boolean          default(TRUE), not null
#  ip_address             :inet
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#

class NsfwProtectFreeze < ApplicationRecord
  belongs_to :account
  belongs_to :nsfw_protect_strike, optional: true

  enum :freeze_type, {
    porn_violation: 0,
    hate_violation: 1,
    illegal_violation: 2,
    csam_violation: 3,
    instance_freeze: 10
  }, prefix: true

  scope :active, -> { where(active: true) }
  scope :expired, -> { where(active: true).where('ends_at < ? AND permanent = false', Time.current) }
  scope :permanent, -> { where(permanent: true) }

  validates :duration_hours, numericality: { greater_than: 0 }
  validates :started_at, presence: true

  before_create :set_ends_at
  after_create :apply_to_account!
  after_save :update_account_freeze_status!

  # Freeze durations based on strike count
  PORN_FREEZE_HOURS = {
    1 => 24,       # 1st: 24 hours
    2 => 72,       # 2nd: 3 days
    3 => 168,      # 3rd: 7 days
    4 => 720,      # 4th: 30 days
    5 => nil       # 5th+: permanent
  }.freeze

  HATE_FREEZE_HOURS = {
    1 => 24,       # 1st: 24 hours (warning)
    2 => 72,       # 2nd: 3 days
    3 => 168,      # 3rd: 7 days
    4 => nil       # 4th+: permanent
  }.freeze

  class << self
    def duration_for_porn_strike(strike_count)
      PORN_FREEZE_HOURS[strike_count] || PORN_FREEZE_HOURS[5]
    end

    def duration_for_hate_strike(strike_count)
      HATE_FREEZE_HOURS[strike_count] || HATE_FREEZE_HOURS[4]
    end

    def expire_old_freezes!
      expired.find_each do |freeze|
        freeze.deactivate!
      end
    end
  end

  def deactivate!
    update!(active: false)
    update_account_freeze_status!
  end

  def time_remaining
    return nil if permanent?
    return 0.seconds if ends_at.nil? || ends_at < Time.current

    ends_at - Time.current
  end

  def expired?
    return false if permanent?

    ends_at.present? && ends_at < Time.current
  end

  private

  def set_ends_at
    self.ends_at = permanent? ? nil : (started_at + duration_hours.hours)
  end

  def apply_to_account!
    account.update!(
      nsfw_frozen_until: ends_at,
      nsfw_permanent_freeze: permanent?,
      nsfw_ever_frozen: true
    )
  end

  def update_account_freeze_status!
    return if account.nsfw_permanent_freeze?

    active_freeze = account.nsfw_protect_freezes.active.order(ends_at: :desc).first

    if active_freeze.nil?
      account.update!(nsfw_frozen_until: nil)
    elsif active_freeze.permanent?
      account.update!(nsfw_frozen_until: nil, nsfw_permanent_freeze: true)
    else
      account.update!(nsfw_frozen_until: active_freeze.ends_at)
    end
  end
end
