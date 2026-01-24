# frozen_string_literal: true

# == Schema Information
#
# Table name: errordon_invite_codes
#
#  id         :bigint(8)        not null, primary key
#  account_id :bigint(8)        not null
#  code       :string           not null
#  uses       :integer          default(0), not null
#  max_uses   :integer          default(3), not null
#  expires_at :datetime
#  active     :boolean          default(TRUE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ErrordonInviteCode < ApplicationRecord
  belongs_to :account
  has_many :users, foreign_key: :errordon_invite_code_id, dependent: :nullify, inverse_of: false

  scope :active, -> { where(active: true) }
  scope :available, -> { active.where('uses < max_uses AND (expires_at IS NULL OR expires_at > ?)', Time.current) }
  scope :by_account, ->(account) { where(account: account) }

  validates :code, presence: true, uniqueness: true
  validates :max_uses, numericality: { greater_than: 0, less_than_or_equal_to: 10 }

  before_validation :generate_code, on: :create

  def available?
    active? && uses < max_uses && (expires_at.nil? || expires_at > Time.current)
  end

  def use!
    return false unless available?

    increment!(:uses)
    deactivate! if uses >= max_uses
    true
  end

  def deactivate!
    update!(active: false)
  end

  def remaining_uses
    [max_uses - uses, 0].max
  end

  class << self
    def find_by_code(code)
      find_by(code: code.to_s.strip.upcase)
    end

    def generate_for_account(account, max_uses: 3, expires_in: nil)
      create!(
        account: account,
        max_uses: max_uses,
        expires_at: expires_in ? Time.current + expires_in : nil
      )
    end

    def invite_only_enabled?
      ENV.fetch('ERRORDON_INVITE_ONLY', 'false').casecmp('true').zero?
    end
  end

  private

  def generate_code
    self.code ||= loop do
      random_code = SecureRandom.alphanumeric(8).upcase
      break random_code unless self.class.exists?(code: random_code)
    end
  end
end
