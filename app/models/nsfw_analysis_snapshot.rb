# frozen_string_literal: true

# == Schema Information
#
# Table name: nsfw_analysis_snapshots
#
#  id                    :bigint(8)        not null, primary key
#  media_attachment_id   :bigint(8)        not null
#  account_id            :bigint(8)        not null
#  nsfw_protect_strike_id :bigint(8)
#  ai_category           :string           not null
#  ai_confidence         :float            not null
#  ai_reason             :text
#  ai_raw_response       :text
#  media_type            :string
#  media_file_size       :integer
#  media_content_type    :string
#  violation_detected    :boolean          default(FALSE), not null
#  marked_for_deletion   :boolean          default(FALSE), not null
#  delete_after          :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#

class NsfwAnalysisSnapshot < ApplicationRecord
  belongs_to :media_attachment
  belongs_to :account
  belongs_to :nsfw_protect_strike, optional: true

  validates :ai_category, presence: true
  validates :ai_confidence, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  # Kategorien
  CATEGORIES = %w[SAFE PORN HATE ILLEGAL CSAM REVIEW].freeze
  VIOLATION_CATEGORIES = %w[PORN HATE ILLEGAL CSAM].freeze

  # Retention: 14 Tage für nicht-Violations
  SAFE_RETENTION_DAYS = 14
  # Violations werden länger behalten (via Strike)
  VIOLATION_RETENTION_DAYS = 365

  scope :safe_only, -> { where(violation_detected: false) }
  scope :violations, -> { where(violation_detected: true) }
  scope :ready_for_deletion, -> { where(marked_for_deletion: false).where('delete_after < ?', Time.current) }
  scope :expired, -> { safe_only.where('delete_after < ?', Time.current) }

  before_create :set_retention_date
  before_create :detect_violation

  class << self
    def create_from_analysis(media_attachment:, account:, result:, strike: nil)
      create!(
        media_attachment: media_attachment,
        account: account,
        nsfw_protect_strike: strike,
        ai_category: result.category,
        ai_confidence: result.confidence,
        ai_reason: result.reason,
        ai_raw_response: result.raw_response,
        media_type: media_attachment.type,
        media_file_size: media_attachment.file_file_size,
        media_content_type: media_attachment.file_content_type,
        violation_detected: result.violation?
      )
    end

    def cleanup_expired!
      count = 0

      expired.find_each do |snapshot|
        snapshot.destroy
        count += 1
      end

      Rails.logger.info "[NSFW-Protect] Cleaned up #{count} expired analysis snapshots"
      count
    end

    def stats
      {
        total: count,
        safe: safe_only.count,
        violations: violations.count,
        pending_deletion: expired.count,
        by_category: group(:ai_category).count,
        oldest: minimum(:created_at),
        newest: maximum(:created_at)
      }
    end
  end

  def safe?
    ai_category == 'SAFE'
  end

  def violation?
    VIOLATION_CATEGORIES.include?(ai_category)
  end

  def days_until_deletion
    return nil if delete_after.nil?
    return 0 if delete_after < Time.current

    ((delete_after - Time.current) / 1.day).ceil
  end

  def extend_retention!(days)
    update!(delete_after: [delete_after, days.days.from_now].max)
  end

  private

  def set_retention_date
    self.delete_after = if violation?
                          VIOLATION_RETENTION_DAYS.days.from_now
                        else
                          SAFE_RETENTION_DAYS.days.from_now
                        end
  end

  def detect_violation
    self.violation_detected = VIOLATION_CATEGORIES.include?(ai_category)
  end
end
