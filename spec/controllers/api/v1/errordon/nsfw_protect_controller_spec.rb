# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Errordon::NsfwProtectController do
  render_views

  let(:admin) { Fabricate(:user, role: UserRole.find_by(name: 'Admin')) }
  let(:user) { Fabricate(:user) }
  let(:admin_token) { Fabricate(:accessible_access_token, resource_owner_id: admin.id, scopes: 'read write admin:read admin:write') }
  let(:user_token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'read write') }

  describe 'GET #status' do
    context 'as admin' do
      before do
        allow(controller).to receive(:doorkeeper_token) { admin_token }
      end

      it 'returns nsfw protect status' do
        get :status
        expect(response).to have_http_status(200)
        expect(response.parsed_body).to have_key('enabled')
      end
    end

    context 'as regular user' do
      before do
        allow(controller).to receive(:doorkeeper_token) { user_token }
      end

      it 'returns forbidden' do
        get :status
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET #config' do
    before do
      allow(controller).to receive(:doorkeeper_token) { admin_token }
    end

    it 'returns current configuration' do
      get :config
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET #stats' do
    before do
      allow(controller).to receive(:doorkeeper_token) { admin_token }
    end

    it 'returns violation statistics' do
      get :stats
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET #alarms' do
    before do
      allow(controller).to receive(:doorkeeper_token) { admin_token }
    end

    it 'returns list of active alarms' do
      get :alarms
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET #blocklist' do
    before do
      allow(controller).to receive(:doorkeeper_token) { admin_token }
    end

    it 'returns blocklist information' do
      get :blocklist
      expect(response).to have_http_status(200)
    end
  end
end
