# frozen_string_literal: true

require 'fileutils'
require 'json'

module Errordon
  # Comprehensive audit logging for NSFW-Protect violations
  # Logs all information needed for law enforcement reports
  class NsfwAuditLogger
    LOG_DIR = Rails.root.join('log', 'nsfw_protect')
    VIOLATIONS_LOG = LOG_DIR.join('violations.log')
    CSAM_LOG = LOG_DIR.join('csam_alerts.log')  # Separate high-priority log
    ADMIN_REPORTS_DIR = LOG_DIR.join('admin_reports')

    class << self
      def setup!
        FileUtils.mkdir_p(LOG_DIR)
        FileUtils.mkdir_p(ADMIN_REPORTS_DIR)
        FileUtils.chmod(0o700, LOG_DIR)  # Restrict access
        FileUtils.chmod(0o700, ADMIN_REPORTS_DIR)
      end

      # Log a violation with full details for potential legal action
      def log_violation(strike:, account:, request_info: {})
        setup!

        entry = build_violation_entry(strike, account, request_info)

        # Write to violations log
        File.open(VIOLATIONS_LOG, 'a') do |f|
          f.puts(entry.to_json)
        end

        # For CSAM, also write to separate high-priority log
        if strike.strike_type_csam?
          File.open(CSAM_LOG, 'a') do |f|
            f.puts(entry.to_json)
          end
        end

        # Generate admin report file for serious violations
        generate_admin_report(entry) if requires_admin_report?(strike)

        Rails.logger.info "[NSFW-Audit] Violation logged: #{strike.strike_type} - Account: #{account.id}"

        entry
      end

      # Generate a complete report for law enforcement
      def generate_law_enforcement_report(strike_id)
        strike = NsfwProtectStrike.find(strike_id)
        account = strike.account
        user = account.user

        report = {
          report_id: SecureRandom.uuid,
          generated_at: Time.current.iso8601,
          platform: {
            name: 'Errordon Instance',
            domain: Rails.configuration.x.local_domain,
            contact: NsfwProtectConfig.current.admin_alert_email
          },
          violation: {
            id: strike.id,
            type: strike.strike_type,
            detected_at: strike.created_at.iso8601,
            ai_confidence: strike.ai_confidence,
            ai_category: strike.ai_category,
            ai_reason: strike.ai_reason,
            law_reference: extract_law_reference(strike)
          },
          suspect_account: {
            account_id: account.id,
            username: account.username,
            display_name: account.display_name,
            created_at: account.created_at.iso8601,
            email: user&.email,
            email_confirmed: user&.confirmed?,
            signup_ip: user&.sign_up_ip&.to_s,
            current_sign_in_ip: user&.current_sign_in_ip&.to_s,
            last_sign_in_ip: user&.last_sign_in_ip&.to_s,
            violation_ip: strike.ip_address&.to_s,
            total_strikes: account.nsfw_strike_count,
            porn_strikes: account.nsfw_porn_strikes,
            hate_strikes: account.nsfw_hate_strikes
          },
          content: {
            status_id: strike.status_id,
            status_url: strike.status&.uri,
            media_attachment_id: strike.media_attachment_id,
            content_text: strike.status&.text&.truncate(500)
          },
          ip_history: collect_ip_history(account),
          previous_violations: collect_previous_violations(account),
          session_info: collect_session_info(user)
        }

        # Save report to file
        report_path = ADMIN_REPORTS_DIR.join("law_enforcement_#{report[:report_id]}.json")
        File.write(report_path, JSON.pretty_generate(report))
        FileUtils.chmod(0o600, report_path)

        report
      end

      # Get summary for admin dashboard
      def violation_summary(days: 30)
        cutoff = days.days.ago

        {
          total: NsfwProtectStrike.where(created_at: cutoff..).count,
          by_type: {
            porn: NsfwProtectStrike.where(created_at: cutoff.., strike_type: :porn).count,
            hate: NsfwProtectStrike.where(created_at: cutoff.., strike_type: :hate).count,
            illegal: NsfwProtectStrike.where(created_at: cutoff.., strike_type: :illegal).count,
            csam: NsfwProtectStrike.where(created_at: cutoff.., strike_type: :csam).count
          },
          unresolved: NsfwProtectStrike.unresolved.count,
          unique_accounts: NsfwProtectStrike.where(created_at: cutoff..).distinct.count(:account_id),
          unique_ips: NsfwProtectStrike.where(created_at: cutoff..).where.not(ip_address: nil).distinct.count(:ip_address)
        }
      end

      private

      def build_violation_entry(strike, account, request_info)
        user = account.user

        {
          timestamp: Time.current.iso8601,
          strike_id: strike.id,
          violation_type: strike.strike_type,
          severity: strike.severity,
          
          # Account identification
          account_id: account.id,
          username: account.username,
          display_name: account.display_name,
          email: user&.email,
          
          # IP addresses (critical for law enforcement)
          violation_ip: strike.ip_address&.to_s,
          signup_ip: user&.sign_up_ip&.to_s,
          current_ip: user&.current_sign_in_ip&.to_s,
          last_ip: user&.last_sign_in_ip&.to_s,
          request_ip: request_info[:ip],
          
          # Request metadata
          user_agent: request_info[:user_agent],
          referrer: request_info[:referrer],
          
          # AI analysis
          ai_confidence: strike.ai_confidence,
          ai_category: strike.ai_category,
          ai_reason: strike.ai_reason,
          
          # Content references
          status_id: strike.status_id,
          media_attachment_id: strike.media_attachment_id,
          
          # Account history
          account_created_at: account.created_at.iso8601,
          total_strikes: account.nsfw_strike_count,
          previous_porn_strikes: account.nsfw_porn_strikes,
          previous_hate_strikes: account.nsfw_hate_strikes
        }
      end

      def requires_admin_report?(strike)
        strike.strike_type_csam? || 
          strike.strike_type_illegal? || 
          (strike.high_confidence? && strike.strike_type_porn?)
      end

      def generate_admin_report(entry)
        report_filename = "violation_#{entry[:strike_id]}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
        report_path = ADMIN_REPORTS_DIR.join(report_filename)
        
        File.write(report_path, JSON.pretty_generate(entry))
        FileUtils.chmod(0o600, report_path)
      end

      def extract_law_reference(strike)
        case strike.strike_type
        when 'csam'
          '§184b StGB (Kinderpornografie)'
        when 'porn'
          '§184 StGB (Verbreitung pornografischer Inhalte)'
        when 'hate'
          '§130 StGB (Volksverhetzung)'
        when 'illegal'
          '§86a StGB (Verwenden von Kennzeichen verfassungswidriger Organisationen)'
        else
          nil
        end
      end

      def collect_ip_history(account)
        user = account.user
        return [] unless user

        ips = []
        ips << { type: 'signup', ip: user.sign_up_ip.to_s, at: user.created_at.iso8601 } if user.sign_up_ip
        ips << { type: 'current_signin', ip: user.current_sign_in_ip.to_s, at: user.current_sign_in_at&.iso8601 } if user.current_sign_in_ip
        ips << { type: 'last_signin', ip: user.last_sign_in_ip.to_s, at: user.last_sign_in_at&.iso8601 } if user.last_sign_in_ip
        
        # Add IPs from previous strikes
        account.nsfw_protect_strikes.where.not(ip_address: nil).order(:created_at).each do |strike|
          ips << { type: 'violation', ip: strike.ip_address.to_s, at: strike.created_at.iso8601 }
        end

        ips.uniq { |i| i[:ip] }
      end

      def collect_previous_violations(account)
        account.nsfw_protect_strikes.order(:created_at).map do |strike|
          {
            id: strike.id,
            type: strike.strike_type,
            created_at: strike.created_at.iso8601,
            resolved: strike.resolved,
            ip: strike.ip_address&.to_s
          }
        end
      end

      def collect_session_info(user)
        return [] unless user

        user.session_activations.order(created_at: :desc).limit(10).map do |session|
          {
            ip: session.ip&.to_s,
            user_agent: session.user_agent,
            created_at: session.created_at.iso8601,
            last_used: session.updated_at.iso8601
          }
        end
      rescue StandardError
        []
      end
    end
  end
end
