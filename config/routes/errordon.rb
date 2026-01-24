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
    end
  end
end
