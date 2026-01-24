# frozen_string_literal: true

module Errordon
  class GdprComplianceService
    # DSGVO/GDPR Compliance Configuration
    # ====================================
    # Art. 5 Abs. 1 lit. e DSGVO: Speicherbegrenzung
    # Daten dürfen nur so lange gespeichert werden, wie es für die Zwecke erforderlich ist.

    RETENTION_PERIODS = {
      # IP-Adressen: 7 Tage für Sicherheitszwecke (BfDI-Empfehlung)
      ip_addresses: 7.days,
      
      # Session-Daten: 30 Tage
      session_data: 30.days,
      
      # Audit-Logs für Violations: 2 Jahre (§184b StGB Dokumentationspflicht bei CSAM)
      violation_logs: 2.years,
      
      # CSAM-Daten: 5 Jahre (Aufbewahrung für Strafverfolgung)
      csam_data: 5.years,
      
      # Reguläre Strikes: 1 Jahr
      regular_strikes: 1.year,
      
      # Anonymisierte Statistiken: unbegrenzt
      anonymized_stats: nil
    }.freeze

    # Rechtsgrundlagen nach Art. 6 DSGVO
    LEGAL_BASIS = {
      content_moderation: 'Art. 6 Abs. 1 lit. f DSGVO (Berechtigtes Interesse)',
      csam_reporting: 'Art. 6 Abs. 1 lit. c DSGVO (Rechtliche Verpflichtung)',
      security_logging: 'Art. 6 Abs. 1 lit. f DSGVO (Berechtigtes Interesse)',
      law_enforcement: 'Art. 6 Abs. 1 lit. c DSGVO (Rechtliche Verpflichtung)'
    }.freeze

    class << self
      # =========================================
      # Art. 17 DSGVO: Recht auf Löschung
      # =========================================
      def delete_user_data(account_id, options = {})
        account = Account.find(account_id)
        user = account.user
        
        Rails.logger.info "[GDPR] Processing deletion request for Account #{account_id}"
        
        deleted_data = {
          account_id: account_id,
          timestamp: Time.current.iso8601,
          items_deleted: []
        }

        ApplicationRecord.transaction do
          # Lösche Strikes (außer bei laufenden Ermittlungen)
          unless options[:preserve_for_investigation]
            strikes = NsfwProtectStrike.where(account: account)
            
            # CSAM-Strikes nur anonymisieren, nicht löschen (rechtliche Pflicht)
            csam_strikes = strikes.where(strike_type: :csam)
            if csam_strikes.any?
              csam_strikes.update_all(
                ip_address: nil,
                ai_analysis_result: '[ANONYMIZED - GDPR REQUEST]'
              )
              deleted_data[:items_deleted] << { type: 'csam_strikes', action: 'anonymized', count: csam_strikes.count }
            end

            # Reguläre Strikes löschen
            regular_strikes = strikes.where.not(strike_type: :csam)
            deleted_data[:items_deleted] << { type: 'regular_strikes', action: 'deleted', count: regular_strikes.count }
            regular_strikes.destroy_all
          end

          # Lösche IP-Adressen aus Account
          anonymize_account_ips(account)
          deleted_data[:items_deleted] << { type: 'ip_addresses', action: 'anonymized' }

          # Lösche User-IP-Daten
          if user.present?
            anonymize_user_ips(user)
            deleted_data[:items_deleted] << { type: 'user_ips', action: 'anonymized' }
          end

          # Lösche Session-Daten
          if defined?(SessionActivation) && user.present?
            user.session_activations.destroy_all
            deleted_data[:items_deleted] << { type: 'sessions', action: 'deleted' }
          end
        end

        # Log der Löschung (DSGVO-konform, ohne personenbezogene Daten)
        log_gdpr_action('deletion', account_id, deleted_data[:items_deleted])

        deleted_data
      end

      # =========================================
      # Art. 15 DSGVO: Auskunftsrecht
      # =========================================
      def export_user_data(account_id)
        account = Account.find(account_id)
        user = account.user

        Rails.logger.info "[GDPR] Processing data export request for Account #{account_id}"

        export = {
          meta: {
            export_date: Time.current.iso8601,
            format_version: '1.0',
            legal_basis: 'Art. 15 DSGVO',
            platform: Rails.configuration.x.local_domain
          },
          
          account_data: {
            id: account.id,
            username: account.username,
            display_name: account.display_name,
            created_at: account.created_at.iso8601,
            note: account.note,
            url: account.url
          },

          user_data: user.present? ? {
            email: user.email,
            created_at: user.created_at.iso8601,
            sign_in_count: user.sign_in_count,
            current_sign_in_at: user.current_sign_in_at&.iso8601,
            last_sign_in_at: user.last_sign_in_at&.iso8601,
            # IP-Adressen nur wenn noch innerhalb Aufbewahrungsfrist
            current_sign_in_ip: ip_within_retention?(user.current_sign_in_at) ? user.current_sign_in_ip&.to_s : '[EXPIRED]',
            last_sign_in_ip: ip_within_retention?(user.last_sign_in_at) ? user.last_sign_in_ip&.to_s : '[EXPIRED]',
            sign_up_ip: ip_within_retention?(user.created_at) ? user.sign_up_ip&.to_s : '[EXPIRED]',
            locale: user.locale,
            confirmed_at: user.confirmed_at&.iso8601
          } : nil,

          nsfw_protect_data: {
            strike_count: account.nsfw_strike_count,
            porn_strikes: account.nsfw_porn_strikes,
            hate_strikes: account.nsfw_hate_strikes,
            frozen_until: account.nsfw_frozen_until&.iso8601,
            permanent_freeze: account.nsfw_permanent_freeze?,
            strikes: export_strikes(account)
          },

          data_retention_info: {
            ip_retention_days: RETENTION_PERIODS[:ip_addresses].to_i / 1.day,
            strike_retention_days: RETENTION_PERIODS[:regular_strikes].to_i / 1.day,
            legal_basis_content_moderation: LEGAL_BASIS[:content_moderation],
            legal_basis_security: LEGAL_BASIS[:security_logging]
          }
        }

        log_gdpr_action('export', account_id, ['full_export'])

        export
      end

      # =========================================
      # Automatische Datenbereinigung (Retention)
      # =========================================
      def cleanup_expired_data!
        Rails.logger.info "[GDPR] Starting automated data retention cleanup"
        
        results = {
          timestamp: Time.current.iso8601,
          actions: []
        }

        # 1. IP-Adressen anonymisieren nach Aufbewahrungsfrist
        ip_cutoff = RETENTION_PERIODS[:ip_addresses].ago
        
        # Strikes: IP anonymisieren
        old_strikes = NsfwProtectStrike.where('created_at < ? AND ip_address IS NOT NULL', ip_cutoff)
                                        .where.not(strike_type: :csam)  # CSAM behält IP länger
        if old_strikes.any?
          count = old_strikes.count
          old_strikes.update_all(ip_address: nil)
          results[:actions] << { type: 'strike_ips_anonymized', count: count }
        end

        # CSAM: IP erst nach längerer Frist anonymisieren
        csam_ip_cutoff = RETENTION_PERIODS[:csam_data].ago
        old_csam = NsfwProtectStrike.where('created_at < ? AND ip_address IS NOT NULL', csam_ip_cutoff)
                                    .where(strike_type: :csam)
        if old_csam.any?
          count = old_csam.count
          old_csam.update_all(ip_address: nil)
          results[:actions] << { type: 'csam_ips_anonymized', count: count }
        end

        # 2. Alte reguläre Strikes löschen
        strike_cutoff = RETENTION_PERIODS[:regular_strikes].ago
        old_regular = NsfwProtectStrike.where('created_at < ?', strike_cutoff)
                                       .where.not(strike_type: :csam)
                                       .where(resolved_at: ..strike_cutoff) # Nur aufgelöste
        if old_regular.any?
          count = old_regular.count
          old_regular.destroy_all
          results[:actions] << { type: 'old_strikes_deleted', count: count }
        end

        # 3. User-IP-Adressen anonymisieren
        if defined?(User)
          User.where('current_sign_in_at < ? AND current_sign_in_ip IS NOT NULL', ip_cutoff)
              .update_all(current_sign_in_ip: nil, last_sign_in_ip: nil)
        end

        # 4. Alte Audit-Logs rotieren
        cleanup_old_audit_logs!

        Rails.logger.info "[GDPR] Cleanup complete: #{results[:actions].map { |a| "#{a[:type]}=#{a[:count]}" }.join(', ')}"

        results
      end

      # =========================================
      # DSGVO-konforme Protokollierung
      # =========================================
      def log_violation_gdpr_compliant(strike:, account:, request_info: {})
        # Minimale Datenspeicherung nach Art. 5 Abs. 1 lit. c DSGVO
        log_entry = {
          timestamp: Time.current.iso8601,
          strike_id: strike.id,
          account_id: account.id,
          strike_type: strike.strike_type,
          ai_confidence: strike.ai_confidence,
          legal_basis: determine_legal_basis(strike),
          # IP nur hashen für Statistik, nicht Klartext speichern
          ip_hash: request_info[:ip].present? ? Digest::SHA256.hexdigest("#{request_info[:ip]}#{Rails.application.secret_key_base}")[0..15] : nil,
          retention_until: calculate_retention_date(strike).iso8601
        }

        # Separates Log für DSGVO-konforme Aufbewahrung
        gdpr_log_path = Rails.root.join('log', 'nsfw_protect', 'gdpr_compliant.log')
        FileUtils.mkdir_p(File.dirname(gdpr_log_path))
        
        File.open(gdpr_log_path, 'a') do |f|
          f.puts(log_entry.to_json)
        end

        log_entry
      end

      private

      def anonymize_account_ips(account)
        account.update_columns(
          last_strike_ip: nil
        ) if account.respond_to?(:last_strike_ip)
      end

      def anonymize_user_ips(user)
        user.update_columns(
          current_sign_in_ip: nil,
          last_sign_in_ip: nil,
          sign_up_ip: nil
        )
      end

      def export_strikes(account)
        account.nsfw_protect_strikes.map do |strike|
          {
            id: strike.id,
            type: strike.strike_type,
            created_at: strike.created_at.iso8601,
            resolved: strike.resolved?,
            resolved_at: strike.resolved_at&.iso8601,
            ai_category: strike.ai_category,
            ai_confidence: strike.ai_confidence,
            # IP nur wenn innerhalb Aufbewahrungsfrist
            ip_address: ip_within_retention?(strike.created_at) ? strike.ip_address&.to_s : '[EXPIRED]',
            retention_info: {
              data_will_be_deleted: calculate_retention_date(strike).iso8601,
              legal_basis: determine_legal_basis(strike)
            }
          }
        end
      end

      def ip_within_retention?(timestamp)
        return false if timestamp.nil?
        timestamp > RETENTION_PERIODS[:ip_addresses].ago
      end

      def determine_legal_basis(strike)
        case strike.strike_type&.to_sym
        when :csam
          LEGAL_BASIS[:csam_reporting]
        else
          LEGAL_BASIS[:content_moderation]
        end
      end

      def calculate_retention_date(strike)
        base_retention = strike.strike_type&.to_sym == :csam ? 
          RETENTION_PERIODS[:csam_data] : 
          RETENTION_PERIODS[:regular_strikes]
        
        strike.created_at + base_retention
      end

      def cleanup_old_audit_logs!
        log_dir = Rails.root.join('log', 'nsfw_protect')
        return unless Dir.exist?(log_dir)

        cutoff = RETENTION_PERIODS[:violation_logs].ago

        Dir.glob(log_dir.join('*.log')).each do |log_file|
          next if File.basename(log_file) == 'csam_alerts.log'  # CSAM logs länger aufbewahren
          
          # Rotiere alte Logs
          if File.mtime(log_file) < cutoff
            archive_path = "#{log_file}.#{cutoff.strftime('%Y%m%d')}.archived"
            FileUtils.mv(log_file, archive_path) if File.exist?(log_file)
          end
        end
      end

      def log_gdpr_action(action, account_id, details)
        gdpr_audit_path = Rails.root.join('log', 'gdpr_audit.log')
        
        entry = {
          timestamp: Time.current.iso8601,
          action: action,
          account_id_hash: Digest::SHA256.hexdigest("#{account_id}#{Rails.application.secret_key_base}")[0..15],
          details: details
        }

        File.open(gdpr_audit_path, 'a') do |f|
          f.puts(entry.to_json)
        end
      end
    end
  end
end
