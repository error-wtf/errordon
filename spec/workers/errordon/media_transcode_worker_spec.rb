# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Errordon::MediaTranscodeWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    context 'when transcoding is disabled' do
      before do
        allow(Rails.application.config.x.errordon_transcoding).to receive(:[]).with(:enabled).and_return(false)
      end

      it 'does nothing when transcoding is disabled' do
        media_attachment = Fabricate(:media_attachment, type: :video)
        
        expect { worker.perform(media_attachment.id) }.not_to raise_error
      end
    end

    context 'when media attachment does not exist' do
      it 'handles missing attachment gracefully' do
        expect { worker.perform(999_999_999) }.not_to raise_error
      end
    end
  end

  describe 'sidekiq options' do
    it 'uses the media queue' do
      expect(described_class.sidekiq_options['queue']).to eq('media')
    end

    it 'retries 3 times' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
  end
end
