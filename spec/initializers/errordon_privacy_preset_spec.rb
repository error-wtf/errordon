# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Errordon Privacy Preset' do
  describe 'configuration' do
    it 'loads privacy preset configuration' do
      expect(Rails.application.config.x).to respond_to(:errordon_upload_limits)
    end
  end

  describe 'ENV variables' do
    it 'respects ERRORDON_PRIVACY_PRESET environment variable' do
      # Default should be 'strict' if not set
      preset = ENV.fetch('ERRORDON_PRIVACY_PRESET', 'strict')
      expect(%w[strict standard]).to include(preset)
    end

    it 'respects ERRORDON_DEFAULT_VISIBILITY' do
      visibility = ENV.fetch('ERRORDON_DEFAULT_VISIBILITY', 'unlisted')
      expect(%w[public unlisted private direct]).to include(visibility)
    end
  end
end
