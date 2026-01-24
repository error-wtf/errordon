# frozen_string_literal: true

# Errordon Privacy Preset Configuration
# Inspired by chaos.social privacy principles
#
# This initializer sets conservative defaults for privacy-conscious instances.
# All settings can be overridden via environment variables or admin UI.

Rails.application.config.to_prepare do
  # === User Defaults ===
  # These affect new user registrations

  # Default post visibility for new users: 'public', 'unlisted', 'private'
  # ENV['ERRORDON_DEFAULT_PRIVACY'] || 'unlisted'

  # Default: don't index user profiles in search engines
  # ENV['ERRORDON_DEFAULT_NOINDEX'] || 'true'

  # Default: require approval for new followers (locked accounts)
  # ENV['ERRORDON_DEFAULT_LOCKED'] || 'false'

  # === Federation Defaults ===

  # Disable full-text search federation by default
  # ENV['ERRORDON_DISABLE_SEARCH_FEDERATION'] || 'true'

  # === Media Defaults ===

  # Disable remote media hotlinking (proxy all remote media)
  # ENV['ERRORDON_PROXY_REMOTE_MEDIA'] || 'true'

  # === Logging & Retention ===

  # IP address retention period (days), 0 = don't store
  # ENV['ERRORDON_IP_RETENTION_DAYS'] || '7'

  # Session retention period (days)
  # ENV['ERRORDON_SESSION_RETENTION_DAYS'] || '30'

  # === Telemetry ===

  # Disable all optional telemetry/analytics
  # ENV['ERRORDON_DISABLE_TELEMETRY'] || 'true'

  # === Rate Limits ===

  # Stricter rate limits for API requests
  # ENV['ERRORDON_STRICT_RATE_LIMITS'] || 'true'
end

# Log that privacy preset is loaded
Rails.logger.info '[Errordon] Privacy preset initializer loaded'
