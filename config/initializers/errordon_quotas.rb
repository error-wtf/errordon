# frozen_string_literal: true

# Errordon User Quotas & Rate Limits
# Prevents abuse of large upload feature
#
# ENV variables:
#   ERRORDON_QUOTA_ENABLED - Enable quota system (default: false)
#   ERRORDON_MAX_STORAGE_GB - Max storage per user in GB (default: 10)
#   ERRORDON_MAX_UPLOADS_HOUR - Max uploads per hour (default: 20)
#   ERRORDON_MAX_DAILY_UPLOAD_GB - Max upload size per day in GB (default: 2)

Rails.application.config.x.errordon_quotas = {
  enabled: ENV.fetch('ERRORDON_QUOTA_ENABLED', 'false') == 'true',

  storage: {
    max_per_user: ENV.fetch('ERRORDON_MAX_STORAGE_GB', '10').to_i.gigabytes
  },

  rate_limits: {
    uploads_per_hour: ENV.fetch('ERRORDON_MAX_UPLOADS_HOUR', '20').to_i,
    upload_size_per_day: ENV.fetch('ERRORDON_MAX_DAILY_UPLOAD_GB', '2').to_i.gigabytes
  },

  # Admin bypass
  exempt_roles: %w[Admin Moderator],

  # Warning thresholds
  warnings: {
    storage_80_percent: true,
    approaching_daily_limit: true
  }
}

# Rack::Attack rate limiting for upload endpoints
if defined?(Rack::Attack) && Rails.application.config.x.errordon_quotas[:enabled]
  Rails.application.config.to_prepare do
    Rack::Attack.throttle('errordon/uploads/ip', 
      limit: Rails.application.config.x.errordon_quotas[:rate_limits][:uploads_per_hour],
      period: 1.hour
    ) do |req|
      if req.path.start_with?('/api/v1/media', '/api/v2/media') && req.post?
        req.ip
      end
    end

    Rack::Attack.throttle('errordon/uploads/user',
      limit: Rails.application.config.x.errordon_quotas[:rate_limits][:uploads_per_hour],
      period: 1.hour
    ) do |req|
      if req.path.start_with?('/api/v1/media', '/api/v2/media') && req.post?
        req.env['warden']&.user&.id
      end
    end

    Rails.logger.info '[Errordon] Upload quota rate limits configured'
  end
end
