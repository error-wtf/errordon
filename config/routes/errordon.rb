# frozen_string_literal: true

# Errordon API Routes
# Add to config/routes.rb: draw(:errordon)

namespace :api do
  namespace :v1 do
    namespace :errordon do
      # User quota endpoint
      get 'quotas/current', to: 'quotas#current'

      # Admin quota management
      resources :quotas, only: [:index, :show, :update]

      # Transcoding status
      get 'transcoding/:media_id/status', to: 'transcoding#status'

      # NSFW-Protect AI Moderation
      namespace :nsfw_protect do
        get 'status', to: 'nsfw_protect#status'
        get 'config', to: 'nsfw_protect#config'
        put 'config', to: 'nsfw_protect#update_config'
        get 'stats', to: 'nsfw_protect#stats'
        post 'test_ollama', to: 'nsfw_protect#test_ollama'

        # Alarm management
        get 'alarms', to: 'nsfw_protect#alarms'
        get 'alarms/:id', to: 'nsfw_protect#show_alarm'
        post 'alarms/:id/resolve', to: 'nsfw_protect#resolve_alarm'
        post 'alarms/:id/dismiss', to: 'nsfw_protect#dismiss_alarm'
      end

      # Invite codes
      resources :invite_codes, only: [:index, :create, :destroy] do
        member do
          post :deactivate
        end
      end
    end
  end
end
