# frozen_string_literal: true

# Errordon NSFW-Protect Configuration
# AI-powered content moderation system
#
# Environment variables:
#   ERRORDON_NSFW_PROTECT_ENABLED    - Enable/disable the system (default: false)
#   ERRORDON_NSFW_OLLAMA_ENDPOINT    - Ollama API endpoint (default: http://localhost:11434)
#   ERRORDON_NSFW_OLLAMA_VISION_MODEL - Vision model for image/video (default: llava)
#   ERRORDON_NSFW_OLLAMA_TEXT_MODEL  - Text model for text analysis (default: llama3)
#   ERRORDON_NSFW_ADMIN_EMAIL        - Admin email for alerts
#   ERRORDON_NSFW_ALARM_THRESHOLD    - Instance freeze threshold (default: 10)
#   ERRORDON_INVITE_ONLY             - Require invite code for registration (default: false)
#   ERRORDON_REQUIRE_AGE_18          - Require 18+ age verification (default: false)

Rails.application.config.x.errordon_nsfw_protect = {
  enabled: ENV.fetch('ERRORDON_NSFW_PROTECT_ENABLED', 'false').casecmp('true').zero?,
  ollama_endpoint: ENV.fetch('ERRORDON_NSFW_OLLAMA_ENDPOINT', 'http://localhost:11434'),
  ollama_vision_model: ENV.fetch('ERRORDON_NSFW_OLLAMA_VISION_MODEL', 'llava'),
  ollama_text_model: ENV.fetch('ERRORDON_NSFW_OLLAMA_TEXT_MODEL', 'llama3'),
  admin_email: ENV.fetch('ERRORDON_NSFW_ADMIN_EMAIL', nil),
  alarm_threshold: ENV.fetch('ERRORDON_NSFW_ALARM_THRESHOLD', '10').to_i,
  invite_only: ENV.fetch('ERRORDON_INVITE_ONLY', 'false').casecmp('true').zero?,
  require_age_18: ENV.fetch('ERRORDON_REQUIRE_AGE_18', 'false').casecmp('true').zero?
}

# Initialize default config in database after Rails loads (if tables exist)
# Skip during asset precompilation or when database is not available
Rails.application.config.after_initialize do
  # Skip if we're precompiling assets or running rake tasks without DB
  next if ENV['SECRET_KEY_BASE_DUMMY'].present?
  next unless ActiveRecord::Base.connected?
  
  begin
    next unless ActiveRecord::Base.connection.table_exists?('nsfw_protect_configs')
    
    config = NsfwProtectConfig.current

    # Sync ENV settings to database on startup (only if not already configured)
    env_config = Rails.application.config.x.errordon_nsfw_protect

    if config.created_at == config.updated_at # Fresh config, apply ENV
      config.update(
        enabled: env_config[:enabled],
        ollama_endpoint: env_config[:ollama_endpoint],
        ollama_vision_model: env_config[:ollama_vision_model],
        ollama_text_model: env_config[:ollama_text_model],
        admin_alert_email: env_config[:admin_email],
        instance_alarm_threshold: env_config[:alarm_threshold]
      )
    end

    Rails.logger.info "[NSFW-Protect] System #{config.enabled? ? 'ENABLED' : 'DISABLED'}"
    Rails.logger.info "[NSFW-Protect] Ollama endpoint: #{config.ollama_endpoint}" if config.enabled?
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid, PG::ConnectionBad => e
    Rails.logger.debug "[NSFW-Protect] Skipping init (DB not ready): #{e.message}"
  end
end
