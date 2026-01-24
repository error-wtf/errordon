# frozen_string_literal: true

module Errordon
  class NsfwProtectMailer < ApplicationMailer
    layout 'mailer'
    helper :accounts

    def new_strike(strike)
      @strike = strike
      @account = strike.account
      @user = @account.user
      @config = NsfwProtectConfig.current
      @domain = Rails.configuration.x.local_domain
      @snapshot = find_snapshot_for_strike(strike)

      return unless @config.admin_alert_email.present?

      # Attach evidence files
      attach_evidence_package(strike, @snapshot)

      mail(
        to: @config.admin_alert_email,
        subject: "[NSFW-Protect] #{strike.strike_type.upcase} violation - @#{@account.username} [Strike ##{strike.id}]"
      )
    end

    def csam_alert(strike)
      @strike = strike
      @account = strike.account
      @user = @account.user
      @config = NsfwProtectConfig.current
      @domain = Rails.configuration.x.local_domain
      @snapshot = find_snapshot_for_strike(strike)

      return unless @config.admin_alert_email.present?

      # CRITICAL: Attach full evidence package for law enforcement
      attach_evidence_package(strike, @snapshot, include_media: true)

      mail(
        to: @config.admin_alert_email,
        subject: "🚨 [CRITICAL] CSAM DETECTED - @#{@account.username} - IMMEDIATE ACTION REQUIRED",
        importance: 'high',
        'X-Priority': '1'
      )
    end

    def instance_frozen(alarm_count)
      @alarm_count = alarm_count
      @config = NsfwProtectConfig.current
      @active_strikes = NsfwProtectStrike.unresolved.includes(:account).limit(20)

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "⚠️ [NSFW-Protect] Instance FROZEN - #{alarm_count} active alarms",
        importance: 'high'
      )
    end

    def instance_unfrozen
      @config = NsfwProtectConfig.current

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "✅ [NSFW-Protect] Instance unfrozen - All alarms resolved"
      )
    end

    def user_frozen(account, freeze)
      @account = account
      @freeze = freeze
      @user = account.user
      @domain = Rails.configuration.x.local_domain

      return unless @user&.email.present?

      I18n.with_locale(@user.locale || I18n.default_locale) do
        mail(
          to: @user.email,
          subject: I18n.t('errordon.nsfw_protect.mailer.user_frozen.subject')
        )
      end
    end

    def weekly_summary
      @config = NsfwProtectConfig.current
      @domain = Rails.configuration.x.local_domain
      @period_start = 1.week.ago.beginning_of_day
      @period_end = Time.current

      @stats = Errordon::NsfwAuditLogger.violation_summary(days: 7)
      @recent_strikes = NsfwProtectStrike.where(created_at: @period_start..).includes(:account).order(created_at: :desc).limit(50)
      @top_violators = Account.where(id: @recent_strikes.map(&:account_id)).order(nsfw_strike_count: :desc).limit(10)
      @blocklist_stats = Errordon::DomainBlocklistService.stats

      return unless @config.admin_alert_email.present?

      mail(
        to: @config.admin_alert_email,
        subject: "📊 [NSFW-Protect] Weekly Summary - #{@period_start.strftime('%Y-%m-%d')} to #{@period_end.strftime('%Y-%m-%d')}"
      )
    end

    private

    def find_snapshot_for_strike(strike)
      # Find snapshot by strike reference or by media attachment
      NsfwAnalysisSnapshot.find_by(nsfw_protect_strike_id: strike.id) ||
        NsfwAnalysisSnapshot.find_by(media_attachment_id: strike.media_attachment_id)
    end

    def attach_evidence_package(strike, snapshot, include_media: false)
      # Filename format: username_YYYY-MM-DD_HH-MM-SS_strikeID
      username = sanitize_filename(strike.account.username)
      date_str = strike.created_at.strftime('%Y-%m-%d')
      time_str = strike.created_at.strftime('%H-%M-%S')
      base_name = "#{username}_#{date_str}_#{time_str}_strike#{strike.id}"
      
      # 1. AI Analysis Report (JSON)
      attachments["#{base_name}_evidence.json"] = {
        mime_type: 'application/json',
        content: generate_evidence_json(strike, snapshot)
      }

      # 2. Human-readable Report (TXT)
      attachments["#{base_name}_evidence.txt"] = {
        mime_type: 'text/plain',
        content: generate_evidence_text(strike, snapshot)
      }

      # 3. If CSAM or requested, attach the actual media (for law enforcement)
      if include_media && strike.media_attachment.present?
        attach_media_evidence(strike, base_name)
      end
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect Mailer] Failed to attach evidence: #{e.message}"
    end

    def generate_evidence_json(strike, snapshot)
      evidence = {
        meta: {
          report_generated: Time.current.iso8601,
          report_type: 'NSFW-Protect AI Analysis Evidence',
          platform: Rails.configuration.x.local_domain,
          legal_notice: 'This report is generated automatically for potential legal proceedings.',
          retention_info: 'Data retained according to GDPR Art. 6(1)(c) - Legal obligation'
        },
        strike: {
          id: strike.id,
          type: strike.strike_type,
          severity: strike.severity,
          created_at: strike.created_at.iso8601,
          ai_category: strike.ai_category,
          ai_confidence: strike.ai_confidence,
          ai_reason: strike.ai_reason
        },
        account: {
          id: strike.account_id,
          username: strike.account.username,
          display_name: strike.account.display_name,
          created_at: strike.account.created_at.iso8601,
          total_strikes: strike.account.nsfw_strike_count
        },
        ai_analysis: snapshot.present? ? {
          snapshot_id: snapshot.id,
          category: snapshot.ai_category,
          confidence: snapshot.ai_confidence,
          reason: snapshot.ai_reason,
          raw_response: snapshot.ai_raw_response,
          analyzed_at: snapshot.created_at.iso8601,
          media_type: snapshot.media_type,
          media_size: snapshot.media_file_size,
          media_content_type: snapshot.media_content_type
        } : nil,
        media_attachment: strike.media_attachment.present? ? {
          id: strike.media_attachment_id,
          type: strike.media_attachment.type,
          file_name: strike.media_attachment.file_file_name,
          file_size: strike.media_attachment.file_file_size,
          content_type: strike.media_attachment.file_content_type,
          created_at: strike.media_attachment.created_at.iso8601
        } : nil,
        ip_address: strike.ip_address&.to_s,
        hash_signatures: generate_content_hashes(strike)
      }

      JSON.pretty_generate(evidence)
    end

    def generate_evidence_text(strike, snapshot)
      <<~TEXT
        ══════════════════════════════════════════════════════════════
        NSFW-PROTECT EVIDENCE REPORT
        ══════════════════════════════════════════════════════════════
        
        Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}
        Platform:  #{Rails.configuration.x.local_domain}
        
        ──────────────────────────────────────────────────────────────
        VIOLATION DETAILS
        ──────────────────────────────────────────────────────────────
        
        Strike ID:       ##{strike.id}
        Type:            #{strike.strike_type.upcase}
        Severity:        #{strike.severity}/5
        Detected:        #{strike.created_at.strftime('%Y-%m-%d %H:%M:%S %Z')}
        
        ──────────────────────────────────────────────────────────────
        ACCOUNT INFORMATION
        ──────────────────────────────────────────────────────────────
        
        Account ID:      #{strike.account_id}
        Username:        @#{strike.account.username}
        Display Name:    #{strike.account.display_name || '(none)'}
        Account Created: #{strike.account.created_at.strftime('%Y-%m-%d')}
        Total Strikes:   #{strike.account.nsfw_strike_count}
        IP Address:      #{strike.ip_address || '(not recorded)'}
        
        ──────────────────────────────────────────────────────────────
        AI ANALYSIS RESULTS
        ──────────────────────────────────────────────────────────────
        
        Category:        #{strike.ai_category}
        Confidence:      #{(strike.ai_confidence * 100).round(1)}%
        Reason:          #{strike.ai_reason}
        
        #{snapshot.present? ? "Snapshot ID:     ##{snapshot.id}\nRaw Response:    #{snapshot.ai_raw_response&.truncate(500)}" : '(No snapshot available)'}
        
        ──────────────────────────────────────────────────────────────
        MEDIA INFORMATION
        ──────────────────────────────────────────────────────────────
        
        #{media_info_text(strike)}
        
        ──────────────────────────────────────────────────────────────
        CONTENT HASHES (for verification)
        ──────────────────────────────────────────────────────────────
        
        #{hash_info_text(strike)}
        
        ══════════════════════════════════════════════════════════════
        LEGAL NOTICE
        ══════════════════════════════════════════════════════════════
        
        This report is generated automatically by the NSFW-Protect system
        for potential use in legal proceedings. Data is retained according
        to GDPR Article 6(1)(c) - Legal obligation.
        
        For CSAM cases: Report to authorities according to local law.
        Germany: BKA Meldestelle (§184b StGB)
        
        ══════════════════════════════════════════════════════════════
      TEXT
    end

    def media_info_text(strike)
      return '(No media attachment)' unless strike.media_attachment.present?

      attachment = strike.media_attachment
      <<~TEXT
        Attachment ID:   #{attachment.id}
        Type:            #{attachment.type}
        File Name:       #{attachment.file_file_name}
        File Size:       #{(attachment.file_file_size.to_f / 1024).round(2)} KB
        Content Type:    #{attachment.file_content_type}
        Uploaded:        #{attachment.created_at.strftime('%Y-%m-%d %H:%M:%S %Z')}
      TEXT
    end

    def hash_info_text(strike)
      hashes = generate_content_hashes(strike)
      return '(No hashes available)' if hashes.empty?

      hashes.map { |k, v| "#{k}: #{v}" }.join("\n")
    end

    def generate_content_hashes(strike)
      hashes = {}
      
      # Hash the AI analysis for integrity verification
      if strike.ai_analysis_result.present?
        hashes['ai_analysis_sha256'] = Digest::SHA256.hexdigest(strike.ai_analysis_result)
      end

      # Hash media file if available
      if strike.media_attachment&.file&.path && File.exist?(strike.media_attachment.file.path)
        hashes['media_sha256'] = Digest::SHA256.file(strike.media_attachment.file.path).hexdigest
      end

      # Hash of strike record
      strike_data = "#{strike.id}|#{strike.account_id}|#{strike.created_at.to_i}|#{strike.strike_type}"
      hashes['strike_record_sha256'] = Digest::SHA256.hexdigest(strike_data)

      hashes
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect] Hash generation failed: #{e.message}"
      {}
    end

    def attach_media_evidence(strike, base_name)
      attachment = strike.media_attachment
      return unless attachment&.file.present?

      extension = File.extname(attachment.file_file_name)
      
      # Try to read the file
      if attachment.file.respond_to?(:download)
        content = attachment.file.download
      elsif attachment.file.respond_to?(:read)
        content = attachment.file.read
      elsif attachment.file.path && File.exist?(attachment.file.path)
        content = File.binread(attachment.file.path)
      else
        Rails.logger.warn "[NSFW-Protect Mailer] Could not read media file for strike #{strike.id}"
        return
      end

      attachments["#{base_name}_media#{extension}"] = {
        mime_type: attachment.file_content_type,
        content: content
      }
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect Mailer] Failed to attach media: #{e.message}"
    end

    def sanitize_filename(name)
      # Remove or replace characters that are problematic in filenames
      name.to_s
          .gsub(/[^a-zA-Z0-9_\-]/, '_')
          .gsub(/_+/, '_')
          .truncate(30, omission: '')
    end
  end
end
