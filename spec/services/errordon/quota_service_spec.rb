# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Errordon::QuotaService do
  let(:user) { Fabricate(:user) }
  let(:account) { user.account }
  let(:service) { described_class.new(account) }

  let(:quota_config) do
    {
      enabled: true,
      storage: { max_per_user: 10.gigabytes },
      rate_limits: {
        uploads_per_hour: 20,
        upload_size_per_day: 2.gigabytes
      },
      exempt_roles: %w[Admin Moderator]
    }
  end

  before do
    allow(Rails.application.config.x).to receive(:errordon_quotas).and_return(quota_config)
  end

  describe '#storage_quota' do
    it 'returns configured quota' do
      expect(service.storage_quota).to eq(10.gigabytes)
    end
  end

  describe '#storage_used' do
    it 'returns 0 when no attachments' do
      expect(service.storage_used).to eq(0)
    end

    context 'with media attachments' do
      before do
        Fabricate(:media_attachment, account: account, file_file_size: 100.megabytes)
        Fabricate(:media_attachment, account: account, file_file_size: 50.megabytes)
      end

      it 'returns sum of attachment sizes' do
        expect(service.storage_used).to eq(150.megabytes)
      end
    end
  end

  describe '#storage_usage_percent' do
    it 'returns 0 when no storage used' do
      expect(service.storage_usage_percent).to eq(0)
    end

    context 'with storage used' do
      before do
        Fabricate(:media_attachment, account: account, file_file_size: 1.gigabyte)
      end

      it 'calculates percentage correctly' do
        expect(service.storage_usage_percent).to eq(10.0)
      end
    end
  end

  describe '#check_upload_allowed!' do
    context 'when quotas disabled' do
      before do
        allow(Rails.application.config.x).to receive(:errordon_quotas).and_return({ enabled: false })
      end

      it 'returns true' do
        expect(service.check_upload_allowed!(500.megabytes)).to be true
      end
    end

    context 'when storage quota exceeded' do
      before do
        Fabricate(:media_attachment, account: account, file_file_size: 9.gigabytes)
      end

      it 'raises QuotaExceededError' do
        expect { service.check_upload_allowed!(2.gigabytes) }
          .to raise_error(Errordon::QuotaService::QuotaExceededError)
      end
    end
  end

  describe '#quota_stats' do
    it 'returns complete stats hash' do
      stats = service.quota_stats

      expect(stats).to include(:storage, :daily, :hourly, :exempt)
      expect(stats[:storage]).to include(:used, :quota, :percent)
      expect(stats[:daily]).to include(:uploaded, :limit, :uploads_count)
      expect(stats[:hourly]).to include(:uploads, :limit)
    end
  end
end
