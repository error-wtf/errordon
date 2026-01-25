# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Errordon::QuotasController do
  render_views

  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:user, role: UserRole.find_by(name: 'Admin')) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'read write') }
  let(:admin_token) { Fabricate(:accessible_access_token, resource_owner_id: admin.id, scopes: 'read write admin:read admin:write') }

  describe 'GET #current' do
    context 'with valid token' do
      before do
        allow(controller).to receive(:doorkeeper_token) { token }
      end

      it 'returns the current user quota' do
        get :current
        expect(response).to have_http_status(200)
      end
    end

    context 'without token' do
      it 'returns unauthorized' do
        get :current
        expect(response).to have_http_status(401)
      end
    end
  end

  describe 'GET #index' do
    context 'as admin' do
      before do
        allow(controller).to receive(:doorkeeper_token) { admin_token }
      end

      it 'returns list of user quotas' do
        get :index
        expect(response).to have_http_status(200)
      end
    end

    context 'as regular user' do
      before do
        allow(controller).to receive(:doorkeeper_token) { token }
      end

      it 'returns forbidden' do
        get :index
        expect(response).to have_http_status(403)
      end
    end
  end
end
