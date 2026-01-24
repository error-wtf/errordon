# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Errordon::VideoTranscoderService do
  let(:account) { Fabricate(:account) }
  let(:media_attachment) { Fabricate(:media_attachment, account: account, type: :video) }
  let(:service) { described_class.new(media_attachment) }

  before do
    allow(Rails.application.config.x).to receive(:errordon_transcoding).and_return({
      enabled: true,
      video: {
        variants: {
          default: { enabled: true, resolution: '1280x720', bitrate: '2500k', preset: 'medium', crf: 23 },
          mobile: { enabled: true, resolution: '854x480', bitrate: '1000k', preset: 'fast', crf: 26 }
        },
        thumbnail: { enabled: true, resolution: '400x225', timestamp: '00:00:01' }
      }
    })
  end

  describe '#call' do
    context 'when transcoding is disabled' do
      before do
        allow(Rails.application.config.x).to receive(:errordon_transcoding).and_return({ enabled: false })
      end

      it 'returns nil' do
        expect(service.call).to be_nil
      end
    end

    context 'when attachment is not a video' do
      let(:media_attachment) { Fabricate(:media_attachment, account: account, type: :image) }

      it 'returns nil' do
        expect(service.call).to be_nil
      end
    end
  end

  describe 'VARIANTS' do
    it 'defines default variant' do
      expect(described_class::VARIANTS[:default]).to include(
        resolution: '1280x720',
        bitrate: '2500k'
      )
    end

    it 'defines mobile variant' do
      expect(described_class::VARIANTS[:mobile]).to include(
        resolution: '854x480',
        bitrate: '1000k'
      )
    end
  end

  describe 'THUMBNAIL_CONFIG' do
    it 'defines thumbnail settings' do
      expect(described_class::THUMBNAIL_CONFIG).to include(
        resolution: '400x225',
        timestamp: '00:00:01'
      )
    end
  end
end
