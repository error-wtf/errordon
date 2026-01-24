# frozen_string_literal: true

module Errordon
  class AuditLogger
    SECURITY_EVENTS = %w[
      file_rejected
      quota_exceeded
      rate_limited
      suspicious_activity
      unauthorized_access
      admin_action
      config_change
      failed_transcode
      malicious_upload
    ].freeze

    class << self
      def log_security_event(event_type, details = {})
        return unless valid_event?(event_type)

        entry = build_entry(event_type, details, :security)
        write_log(entry)
        notify_if_critical(event_type, entry)
      end

      def log_admin_action(action, admin_account, target, details = {})
        entry = build_entry(:admin_action, {
          action: action,
          admin_id: admin_account&.id,
          admin_username: admin_account&.username,
          target_type: target.class.name,
          target_id: target.try(:id),
          details: details
        }, :admin)

        write_log(entry)
      end

      def log_upload(account, media_attachment, request_info = {})
        entry = build_entry(:upload, {
          account_id: account.id,
          username: account.username,
          media_id: media_attachment.id,
          file_type: media_attachment.type,
          file_size: media_attachment.file_file_size,
          filename: media_attachment.file_file_name,
          ip: request_info[:ip],
          user_agent: sanitize_user_agent(request_info[:user_agent])
        }, :activity)

        write_log(entry)
      end

      def log_quota_warning(account, warning_type, details = {})
        entry = build_entry(:quota_warning, {
          account_id: account.id,
          username: account.username,
          warning_type: warning_type,
          details: details
        }, :warning)

        write_log(entry)
      end

      def recent_events(event_type: nil, severity: nil, limit: 100)
        # In production, this would query a database or log aggregation service
        # For now, return empty array - implement based on your logging backend
        []
      end

      private

      def valid_event?(event_type)
        SECURITY_EVENTS.include?(event_type.to_s)
      end

      def build_entry(event_type, details, severity)
        {
          timestamp: Time.current.iso8601(3),
          event_type: event_type.to_s,
          severity: severity.to_s,
          service: 'errordon',
          environment: Rails.env,
          details: sanitize_details(details),
          request_id: Thread.current[:request_id]
        }
      end

      def sanitize_details(details)
        details.transform_values do |value|
          case value
          when String
            # Truncate very long strings
            value.length > 1000 ? "#{value[0...1000]}..." : value
          when Hash
            sanitize_details(value)
          else
            value
          end
        end
      end

      def sanitize_user_agent(user_agent)
        return nil if user_agent.blank?

        # Truncate and remove potentially dangerous characters
        user_agent.to_s.gsub(/[<>"']/, '')[0...500]
      end

      def write_log(entry)
        # Write to Rails logger
        logger_method = case entry[:severity]
                        when 'security' then :warn
                        when 'warning' then :warn
                        else :info
                        end

        Rails.logger.public_send(logger_method, "[Errordon::Audit] #{entry.to_json}")

        # Write to dedicated audit log file if configured
        write_to_audit_file(entry) if audit_file_enabled?

        # Send to external logging service if configured
        send_to_external_service(entry) if external_logging_enabled?
      end

      def write_to_audit_file(entry)
        File.open(audit_log_path, 'a') do |f|
          f.puts(entry.to_json)
        end
      rescue StandardError => e
        Rails.logger.error "[Errordon::Audit] Failed to write audit log: #{e.message}"
      end

      def audit_log_path
        Rails.root.join('log', "errordon_audit_#{Rails.env}.log")
      end

      def audit_file_enabled?
        ENV.fetch('ERRORDON_AUDIT_FILE', 'true') == 'true'
      end

      def external_logging_enabled?
        ENV['ERRORDON_AUDIT_WEBHOOK_URL'].present?
      end

      def send_to_external_service(entry)
        # Async webhook to external logging service
        return unless external_logging_enabled?

        # Use a background job to avoid blocking
        ErrordonAuditWebhookJob.perform_later(entry) if defined?(ErrordonAuditWebhookJob)
      rescue StandardError => e
        Rails.logger.error "[Errordon::Audit] Failed to send to external service: #{e.message}"
      end

      def notify_if_critical(event_type, entry)
        critical_events = %w[malicious_upload unauthorized_access suspicious_activity]

        return unless critical_events.include?(event_type.to_s)

        # Send notification to admins
        notify_admins(entry)
      end

      def notify_admins(entry)
        # In production, implement admin notification (email, Slack, etc.)
        Rails.logger.error "[Errordon::CRITICAL] Security event requires attention: #{entry[:event_type]}"
      end
    end
  end
end
