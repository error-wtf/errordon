# frozen_string_literal: true

namespace :errordon do
  namespace :nsfw_protect do
    desc 'Update porn domain blocklist from external sources'
    task update_blocklist: :environment do
      puts "Updating NSFW-Protect domain blocklist..."
      result = Errordon::DomainBlocklistService.update_blocklist!
      
      if result[:success]
        puts "✓ Blocklist updated: #{result[:count]} domains"
      else
        puts "✗ Update failed: #{result[:error]}"
        exit 1
      end
    end

    desc 'Show blocklist statistics'
    task blocklist_stats: :environment do
      stats = Errordon::DomainBlocklistService.stats
      
      puts "NSFW-Protect Domain Blocklist Statistics"
      puts "=" * 40
      puts "Total domains: #{stats[:total_domains]}"
      puts "Hardcoded domains: #{stats[:hardcoded_count]}"
      puts "File exists: #{stats[:file_exists]}"
      puts "Last updated: #{stats[:last_updated] || 'Never'}"
      puts "Sources: #{stats[:sources].join(', ')}"
    end

    desc 'Check if a domain is blocked'
    task :check_domain, [:domain] => :environment do |_t, args|
      domain = args[:domain]
      
      if domain.blank?
        puts "Usage: rake errordon:nsfw_protect:check_domain[example.com]"
        exit 1
      end

      blocked = Errordon::DomainBlocklistService.blocked?(domain)
      puts "#{domain}: #{blocked ? '🚫 BLOCKED' : '✓ Allowed'}"
    end

    desc 'Show violation summary for last N days'
    task :violation_summary, [:days] => :environment do |_t, args|
      days = (args[:days] || 30).to_i
      summary = Errordon::NsfwAuditLogger.violation_summary(days: days)
      
      puts "NSFW-Protect Violation Summary (Last #{days} days)"
      puts "=" * 50
      puts "Total violations: #{summary[:total]}"
      puts ""
      puts "By type:"
      puts "  Porn: #{summary[:by_type][:porn]}"
      puts "  Hate: #{summary[:by_type][:hate]}"
      puts "  Illegal: #{summary[:by_type][:illegal]}"
      puts "  CSAM: #{summary[:by_type][:csam]}"
      puts ""
      puts "Unresolved: #{summary[:unresolved]}"
      puts "Unique accounts: #{summary[:unique_accounts]}"
      puts "Unique IPs: #{summary[:unique_ips]}"
    end

    desc 'Generate law enforcement report for a strike'
    task :generate_report, [:strike_id] => :environment do |_t, args|
      strike_id = args[:strike_id]
      
      if strike_id.blank?
        puts "Usage: rake errordon:nsfw_protect:generate_report[123]"
        exit 1
      end

      begin
        report = Errordon::NsfwAuditLogger.generate_law_enforcement_report(strike_id)
        puts "✓ Report generated: #{report[:report_id]}"
        puts "  Saved to: log/nsfw_protect/admin_reports/law_enforcement_#{report[:report_id]}.json"
      rescue ActiveRecord::RecordNotFound
        puts "✗ Strike not found: #{strike_id}"
        exit 1
      end
    end

    desc 'Setup NSFW-Protect directories and initial data'
    task setup: :environment do
      puts "Setting up NSFW-Protect..."
      
      # Create directories
      Errordon::NsfwAuditLogger.setup!
      puts "✓ Audit log directories created"
      
      # Update blocklist
      result = Errordon::DomainBlocklistService.update_blocklist!
      if result[:success]
        puts "✓ Domain blocklist initialized: #{result[:count]} domains"
      else
        puts "⚠ Blocklist update failed (using hardcoded list)"
      end
      
      puts ""
      puts "NSFW-Protect setup complete!"
    end
  end

  # =============================================
  # DSGVO/GDPR Compliance Tasks
  # =============================================
  namespace :gdpr do
    desc 'Run GDPR data retention cleanup (anonymize/delete expired data)'
    task cleanup: :environment do
      puts "Running GDPR data retention cleanup..."
      result = Errordon::GdprComplianceService.cleanup_expired_data!
      
      if result[:actions].any?
        puts "✓ Cleanup complete:"
        result[:actions].each do |action|
          puts "  - #{action[:type]}: #{action[:count]} items"
        end
      else
        puts "✓ No data to clean up"
      end
    end

    desc 'Export user data (Art. 15 DSGVO)'
    task :export, [:account_id] => :environment do |_t, args|
      account_id = args[:account_id]
      
      if account_id.blank?
        puts "Usage: rake errordon:gdpr:export[account_id]"
        exit 1
      end

      puts "Exporting data for Account #{account_id}..."
      export = Errordon::GdprComplianceService.export_user_data(account_id)
      
      # Save to file
      filename = "gdpr_export_#{account_id}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
      filepath = Rails.root.join('tmp', filename)
      File.write(filepath, JSON.pretty_generate(export))
      
      puts "✓ Export saved to: #{filepath}"
    end

    desc 'Delete user data (Art. 17 DSGVO)'
    task :delete, [:account_id] => :environment do |_t, args|
      account_id = args[:account_id]
      
      if account_id.blank?
        puts "Usage: rake errordon:gdpr:delete[account_id]"
        exit 1
      end

      account = Account.find(account_id)
      
      # Check for CSAM
      if account.nsfw_protect_strikes.where(strike_type: :csam).exists?
        puts "⚠ WARNUNG: Account hat CSAM-Strikes!"
        puts "  Diese Daten können aufgrund §184b StGB nicht gelöscht werden."
        puts "  Kontaktieren Sie den Datenschutzbeauftragten."
        exit 1
      end

      print "Wirklich alle Daten für @#{account.username} löschen? (yes/no): "
      confirm = $stdin.gets.chomp
      
      unless confirm == 'yes'
        puts "Abgebrochen."
        exit 0
      end

      puts "Lösche Daten für Account #{account_id}..."
      result = Errordon::GdprComplianceService.delete_user_data(account_id)
      
      puts "✓ Löschung abgeschlossen:"
      result[:items_deleted].each do |item|
        puts "  - #{item[:type]}: #{item[:action]} (#{item[:count] || 'n/a'})"
      end
    end

    desc 'Show retention info for an account'
    task :retention_info, [:account_id] => :environment do |_t, args|
      account_id = args[:account_id]
      
      if account_id.blank?
        puts "Usage: rake errordon:gdpr:retention_info[account_id]"
        exit 1
      end

      account = Account.find(account_id)
      puts "DSGVO Aufbewahrungsinfo für @#{account.username}"
      puts "=" * 50
      puts ""
      puts "Strikes: #{account.nsfw_protect_strikes.count}"
      
      account.nsfw_protect_strikes.each do |strike|
        retention = strike.strike_type&.to_sym == :csam ? 5.years : 1.year
        delete_at = strike.created_at + retention
        ip_anon_at = strike.created_at + 7.days
        
        puts ""
        puts "Strike ##{strike.id} (#{strike.strike_type})"
        puts "  Erstellt: #{strike.created_at}"
        puts "  IP anonymisiert: #{strike.ip_address.nil? ? '✓ Ja' : ip_anon_at}"
        puts "  Löschung geplant: #{delete_at}"
      end
    end

    desc 'Show GDPR retention policy'
    task policy: :environment do
      puts "DSGVO Aufbewahrungsrichtlinien"
      puts "=" * 50
      puts ""
      
      Errordon::GdprComplianceService::RETENTION_PERIODS.each do |key, duration|
        if duration.nil?
          puts "#{key}: unbegrenzt (anonymisiert)"
        else
          days = duration.to_i / 1.day
          puts "#{key}: #{days} Tage"
        end
      end
      
      puts ""
      puts "Rechtsgrundlagen:"
      Errordon::GdprComplianceService::LEGAL_BASIS.each do |key, basis|
        puts "  #{key}: #{basis}"
      end
    end

    desc 'Cleanup expired AI analysis snapshots (14 days for safe results)'
    task cleanup_snapshots: :environment do
      puts "AI Analysis Snapshot Cleanup"
      puts "=" * 50
      puts ""

      stats = NsfwAnalysisSnapshot.stats
      puts "Aktuelle Statistiken:"
      puts "  Gesamt:           #{stats[:total]}"
      puts "  SAFE:             #{stats[:safe]}"
      puts "  Violations:       #{stats[:violations]}"
      puts "  Zur Löschung:     #{stats[:pending_deletion]}"
      puts ""

      if stats[:pending_deletion] == 0
        puts "✓ Keine abgelaufenen Snapshots zu löschen"
        exit 0
      end

      print "#{stats[:pending_deletion]} Snapshots löschen? [y/N] "
      confirm = $stdin.gets.chomp.downcase

      unless confirm == 'y'
        puts "Abgebrochen."
        exit 0
      end

      puts ""
      puts "Lösche abgelaufene Snapshots..."

      deleted = NsfwAnalysisSnapshot.cleanup_expired!

      puts ""
      puts "✓ #{deleted} Snapshots gelöscht"
    end

    desc 'Show AI analysis snapshot statistics'
    task snapshot_stats: :environment do
      puts "AI Analysis Snapshot Statistiken"
      puts "=" * 50
      puts ""

      stats = NsfwAnalysisSnapshot.stats

      puts "Übersicht:"
      puts "  Gesamt:           #{stats[:total]}"
      puts "  SAFE:             #{stats[:safe]} (werden nach 14 Tagen gelöscht)"
      puts "  Violations:       #{stats[:violations]} (werden länger behalten)"
      puts "  Zur Löschung:     #{stats[:pending_deletion]}"
      puts ""

      if stats[:by_category].any?
        puts "Nach Kategorie:"
        stats[:by_category].each do |cat, count|
          puts "  #{cat}: #{count}"
        end
        puts ""
      end

      puts "Zeitraum:"
      puts "  Ältester:         #{stats[:oldest]&.strftime('%Y-%m-%d %H:%M') || '-'}"
      puts "  Neuester:         #{stats[:newest]&.strftime('%Y-%m-%d %H:%M') || '-'}"
    end

    desc 'Generate GDPR compliance report'
    task report: :environment do
      puts "DSGVO Compliance Report"
      puts "=" * 50
      puts "Generiert: #{Time.current}"
      puts ""
      
      # Statistiken
      total_strikes = NsfwProtectStrike.count
      strikes_with_ip = NsfwProtectStrike.where.not(ip_address: nil).count
      old_ips = NsfwProtectStrike.where('created_at < ? AND ip_address IS NOT NULL', 7.days.ago)
                                 .where.not(strike_type: :csam).count
      
      puts "Strike-Statistiken:"
      puts "  Gesamt: #{total_strikes}"
      puts "  Mit IP-Adresse: #{strikes_with_ip}"
      puts "  IPs zur Anonymisierung fällig: #{old_ips}"
      puts ""
      
      # Alte Daten
      old_strikes = NsfwProtectStrike.where('created_at < ?', 1.year.ago)
                                     .where.not(strike_type: :csam).count
      puts "Zur Löschung fällig:"
      puts "  Reguläre Strikes älter als 1 Jahr: #{old_strikes}"
      puts ""
      
      # Empfehlung
      if old_ips > 0 || old_strikes > 0
        puts "⚠ AKTION ERFORDERLICH:"
        puts "  Führen Sie 'rake errordon:gdpr:cleanup' aus"
      else
        puts "✓ Alle Daten entsprechen den Aufbewahrungsfristen"
      end
    end
  end
end
