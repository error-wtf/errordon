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
end
