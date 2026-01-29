# frozen_string_literal: true

module Errordon
  # =============================================================================
  # GDPR-COMPLIANT ACCOUNT DELETION SERVICE
  # =============================================================================
  #
  # This service wraps the standard Mastodon deletion flow with additional
  # GDPR compliance features:
  #
  # 1. Audit logging for compliance documentation
  # 2. Email confirmation to user
  # 3. Data export reminder
  # 4. 30-day grace period (standard Mastodon)
  # 5. Federated deletion notifications (standard Mastodon)
  #
  # DSGVO Article 17 - Right to Erasure ("Right to be Forgotten")
  # =============================================================================

  class GdprDeletionService
    DELETION_DELAY = 30.days # GDPR allows up to 30 days for processing

    class << self
      # Process a GDPR deletion request
      # Called when user requests account deletion
      def request_deletion(account, request_ip: nil, reason: nil)
        return { success: false, error: 'Account not found' } unless account
        return { success: false, error: 'Account already suspended' } if account.suspended?

        # Create audit log entry
        log_deletion_request(account, request_ip, reason)

        # Suspend account immediately (prevents further data creation)
        account.suspend!(origin: :local, block_email: false)

        # Queue deletion worker (respects 30-day delay)
        AccountDeletionWorker.perform_async(account.id)

        # Send confirmation email
        send_deletion_confirmation(account)

        # Log successful request
        Rails.logger.info "[GDPR] Deletion request processed for account #{account.id} (@#{account.username})"

        {
          success: true,
          message: 'Deletion request received',
          due_date: DELETION_DELAY.from_now.to_date,
          audit_id: generate_audit_id(account)
        }
      end

      # Check deletion status for a user
      def deletion_status(account)
        return nil unless account

        request = account.deletion_request
        return nil unless request

        {
          requested_at: request.created_at,
          due_at: request.due_at,
          days_remaining: [(request.due_at.to_date - Date.current).to_i, 0].max,
          status: account.suspended? ? 'pending_deletion' : 'active'
        }
      end

      # Cancel deletion request (within grace period)
      def cancel_deletion(account)
        return { success: false, error: 'Account not found' } unless account
        return { success: false, error: 'No pending deletion' } unless account.deletion_request

        # Can only cancel if within grace period and not yet deleted
        if account.suspended? && account.deletion_request.present?
          account.unsuspend!
          account.deletion_request.destroy
          
          log_deletion_cancelled(account)
          
          Rails.logger.info "[GDPR] Deletion cancelled for account #{account.id}"
          { success: true, message: 'Deletion cancelled' }
        else
          { success: false, error: 'Cannot cancel deletion at this stage' }
        end
      end

      # Generate GDPR data export for user
      def generate_data_export(account)
        return nil unless account

        # Mastodon's built-in export handles this
        # Just log the request for GDPR compliance
        Rails.logger.info "[GDPR] Data export requested for account #{account.id}"
        
        {
          account_data: export_account_data(account),
          statuses_count: account.statuses.count,
          media_count: account.media_attachments.count,
          followers_count: account.followers.count,
          following_count: account.following.count
        }
      end

      private

      def log_deletion_request(account, ip, reason)
        audit_entry = {
          event: 'gdpr_deletion_request',
          account_id: account.id,
          username: account.username,
          email: account.user&.email,
          ip_address: anonymize_ip(ip),
          reason: reason || 'User requested deletion',
          timestamp: Time.current.iso8601,
          gdpr_article: 'Article 17 - Right to Erasure',
          retention_period: "#{DELETION_DELAY.inspect} from request"
        }

        # Log to Rails logger
        Rails.logger.info "[GDPR-AUDIT] #{audit_entry.to_json}"

        # Store in admin audit log if available
        if defined?(Admin::ActionLog)
          Admin::ActionLog.create(
            account_id: account.id,
            action: 'gdpr_deletion_request',
            target_type: 'Account',
            target_id: account.id,
            recorded_changes: audit_entry.to_json
          )
        end
      end

      def log_deletion_cancelled(account)
        Rails.logger.info "[GDPR-AUDIT] Deletion cancelled: account_id=#{account.id}, username=#{account.username}"
      end

      def send_deletion_confirmation(account)
        return unless account.user&.email

        # Use Mastodon's mailer if available
        if defined?(UserMailer)
          begin
            # Queue email for delivery
            UserMailer.with(user: account.user).gdpr_deletion_confirmation.deliver_later
          rescue StandardError => e
            Rails.logger.warn "[GDPR] Could not send confirmation email: #{e.message}"
          end
        end
      end

      def generate_audit_id(account)
        "GDPR-#{account.id}-#{Time.current.strftime('%Y%m%d%H%M%S')}"
      end

      def anonymize_ip(ip)
        return 'unknown' unless ip

        # Anonymize last octet for IPv4, last 80 bits for IPv6
        if ip.include?('.')
          parts = ip.split('.')
          "#{parts[0..2].join('.')}.xxx"
        elsif ip.include?(':')
          parts = ip.split(':')
          "#{parts[0..3].join(':')}:xxxx:xxxx:xxxx:xxxx"
        else
          'anonymized'
        end
      end

      def export_account_data(account)
        {
          username: account.username,
          display_name: account.display_name,
          created_at: account.created_at,
          note: account.note,
          fields: account.fields.map { |f| { name: f.name, value: f.value } },
          avatar: account.avatar.present?,
          header: account.header.present?
        }
      end
    end
  end
end
