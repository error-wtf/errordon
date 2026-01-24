# frozen_string_literal: true

module ErrordonSecurityConcern
  extend ActiveSupport::Concern

  included do
    before_action :validate_security_headers, if: :errordon_endpoint?
    before_action :check_rate_limits, if: :errordon_endpoint?
    before_action :log_request, if: :errordon_endpoint?

    rescue_from Errordon::SecurityService::SecurityViolationError, with: :handle_security_violation
    rescue_from Errordon::QuotaService::QuotaExceededError, with: :handle_quota_exceeded
    rescue_from Errordon::QuotaService::RateLimitExceededError, with: :handle_rate_limited
  end

  private

  def errordon_endpoint?
    # Override in controllers if needed
    request.path.include?('/errordon') || media_upload_request?
  end

  def media_upload_request?
    request.path.start_with?('/api/v1/media', '/api/v2/media') && request.post?
  end

  def validate_security_headers
    config = Rails.application.config.x.errordon_security[:request]

    # Check User-Agent
    if config[:require_user_agent] && request.user_agent.blank?
      record_security_violation(:missing_user_agent)
      render json: { error: 'User-Agent header required' }, status: :bad_request
      return false
    end

    # Check Content-Length for uploads
    if media_upload_request?
      content_length = request.content_length.to_i
      max_size = config[:max_body_size]

      if content_length > max_size
        record_security_violation(:oversized_request, { size: content_length, max: max_size })
        render json: { error: 'Request too large' }, status: :payload_too_large
        return false
      end
    end

    true
  end

  def check_rate_limits
    return true unless current_account

    quota_service = Errordon::QuotaService.new(current_account)

    if media_upload_request?
      # Pre-check rate limits before processing upload
      stats = quota_service.quota_stats

      if stats[:hourly][:uploads] >= stats[:hourly][:limit]
        record_security_violation(:rate_limit_precheck)
        render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
        return false
      end
    end

    true
  end

  def log_request
    return unless Rails.application.config.x.errordon_security[:audit][:enabled]

    details = {
      ip: request.remote_ip,
      user_agent: request.user_agent&.truncate(200),
      path: request.path,
      method: request.method,
      user_id: current_user&.id,
      account_id: current_account&.id
    }

    Rails.logger.info "[Errordon::Request] #{details.to_json}"
  end

  def validate_uploaded_file(file)
    return true if file.blank?

    security_service = Errordon::SecurityService.new(file, {
      ip: request.remote_ip,
      user_id: current_user&.id
    })

    security_service.validate!
  end

  def handle_security_violation(exception)
    record_security_violation(:file_validation_failed, { message: exception.message })

    render json: {
      error: 'Security validation failed',
      message: 'The uploaded file was rejected for security reasons'
    }, status: :unprocessable_entity
  end

  def handle_quota_exceeded(exception)
    Errordon::AuditLogger.log_quota_warning(current_account, :exceeded, {
      message: exception.message
    })

    render json: {
      error: 'Quota exceeded',
      message: exception.message
    }, status: :payload_too_large
  end

  def handle_rate_limited(exception)
    Errordon::AuditLogger.log_security_event(:rate_limited, {
      account_id: current_account&.id,
      ip: request.remote_ip,
      message: exception.message
    })

    render json: {
      error: 'Rate limit exceeded',
      message: exception.message,
      retry_after: 3600
    }, status: :too_many_requests
  end

  def record_security_violation(type, details = {})
    violation_details = details.merge(
      type: type,
      ip: request.remote_ip,
      user_agent: request.user_agent,
      path: request.path,
      user_id: current_user&.id,
      account_id: current_account&.id,
      timestamp: Time.current.iso8601
    )

    Errordon::AuditLogger.log_security_event(:suspicious_activity, violation_details)

    # Increment violation counter for IP blocking
    increment_violation_counter(request.remote_ip)
  end

  def increment_violation_counter(ip)
    return unless defined?(Rack::Attack)

    key = "errordon:security:#{ip}"
    count = Rack::Attack.cache.read(key).to_i + 1

    # Store with 24 hour expiry
    Rack::Attack.cache.write(key, count, 24.hours)

    # Auto-block if threshold exceeded
    config = Rails.application.config.x.errordon_security
    if count >= config[:rate_limits][:security_violations_per_day]
      Rails.logger.warn "[Errordon::Security] Auto-blocking IP #{ip} after #{count} violations"
      Errordon::AuditLogger.log_security_event(:ip_blocked, { ip: ip, violations: count })
    end
  end
end
