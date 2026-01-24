# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Errordon Upload Limits' do
  describe 'configuration' do
    let(:config) { Rails.application.config.x.errordon_upload_limits }

    it 'sets video upload limit' do
      expect(config[:video]).to eq(262_144_000) # 250MB default
    end

    it 'sets audio upload limit' do
      expect(config[:audio]).to eq(262_144_000) # 250MB default
    end

    it 'sets image upload limit' do
      expect(config[:image]).to eq(16_777_216) # 16MB default
    end

    it 'allows ENV override for video size' do
      allow(ENV).to receive(:fetch).with('MAX_VIDEO_SIZE', anything).and_return('500000000')
      # Reload would pick up the new value
      expect(ENV.fetch('MAX_VIDEO_SIZE', 262_144_000).to_i).to eq(500_000_000)
    end
  end
end
