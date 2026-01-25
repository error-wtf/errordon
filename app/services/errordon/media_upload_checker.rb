# frozen_string_literal: true

module Errordon
  class MediaUploadChecker
    class ViolationError < StandardError
      attr_reader :analysis_result, :violation_type

      def initialize(message, analysis_result, violation_type: :content)
        super(message)
        @analysis_result = analysis_result
        @violation_type = violation_type
      end
    end

    class QuotaExceededError < StandardError
      attr_reader :quota_info

      def initialize(message, quota_info)
        super(message)
        @quota_info = quota_info
      end
    end

    def initialize(media_attachment, ip_address: nil, request: nil)
      @attachment = media_attachment
      @account = media_attachment.account
      @ip_address = ip_address || extract_ip_from_request(request)
      @user_agent = request&.user_agent
      @request = request
      @config = NsfwProtectConfig.current
      @analyzer = OllamaContentAnalyzer.new
    end

    def call
      return true unless should_check?

      # Check if account is frozen
      raise_if_frozen!

      # Check storage quota BEFORE processing upload
      check_storage_quota!

      # Check for blocked URLs in status text
      check_blocked_urls! if @attachment.status.present?

      # Analyze the media
      result = analyze_media

      # If violation detected, create strike and raise error
      if result.violation?
        handle_violation!(result)
        raise ViolationError.new("Content violation detected: #{result.category}", result)
      end

      # If needs review, flag for manual check but allow upload
      if result.needs_review?
        flag_for_review!(result)
        create_analysis_snapshot(result)
      end

      # Create snapshot for SAFE results too (will be auto-deleted after 14 days)
      if result.safe?
        create_analysis_snapshot(result)
      end

      true
    end

    def check_without_raising
      call
      { allowed: true, result: nil }
    rescue ViolationError => e
      { allowed: false, result: e.analysis_result }
    end

    private

    def should_check?
      return false unless @config.enabled?
      return false unless @config.porn_detection_enabled?
      return false unless @attachment.present?
      return false unless %w[image video].include?(@attachment.type)
      
      # Admins sind von NSFW-Checks ausgenommen (für Testing)
      return false if admin_account?

      true
    end

    def admin_account?
      return false unless @account.present?
      
      user = @account.user
      return false unless user.present?
      
      user.admin? || user.moderator?
    end

    def raise_if_frozen!
      return unless account_frozen?

      freeze_message = if @account.nsfw_permanent_freeze?
                         'Your account has been permanently frozen due to content policy violations.'
                       else
                         "Your account is frozen until #{@account.nsfw_frozen_until.strftime('%Y-%m-%d %H:%M UTC')}."
                       end

      raise ViolationError.new(freeze_message, nil)
    end

    def account_frozen?
      return true if @account.nsfw_permanent_freeze?
      return true if @account.nsfw_frozen_until.present? && @account.nsfw_frozen_until > Time.current

      # Check instance-wide freeze for accounts that have been frozen before
      return true if @config.instance_frozen? && @account.nsfw_ever_frozen?

      false
    end

    def analyze_media
      file_path = @attachment.file.path || download_to_temp

      case @attachment.type
      when 'image'
        @analyzer.analyze_image(file_path)
      when 'video'
        @analyzer.analyze_video(file_path)
      else
        OllamaContentAnalyzer::AnalysisResult.new(
          category: 'SAFE',
          confidence: 1.0,
          reason: 'Unsupported media type'
        )
      end
    ensure
      cleanup_temp_file
    end

    def download_to_temp
      return nil unless @attachment.file.present?

      @temp_file = Tempfile.new(['nsfw_check', File.extname(@attachment.file_file_name)])
      @temp_file.binmode

      if @attachment.file.respond_to?(:download)
        @temp_file.write(@attachment.file.download)
      elsif @attachment.file.respond_to?(:read)
        @temp_file.write(@attachment.file.read)
      end

      @temp_file.close
      @temp_file.path
    end

    def cleanup_temp_file
      @temp_file&.unlink
    rescue StandardError
      nil
    end

    def handle_violation!(result)
      strike = NsfwProtectStrike.create!(
        account: @account,
        media_attachment: @attachment,
        strike_type: result.to_strike_type,
        severity: calculate_severity(result),
        ip_address: @ip_address,
        ai_analysis_result: result.raw_response,
        ai_confidence: result.confidence,
        ai_category: result.category,
        ai_reason: result.reason
      )

      # Create analysis snapshot (for violations - kept longer)
      create_analysis_snapshot(result, strike: strike)

      Rails.logger.warn "[NSFW-Protect] Violation detected: Account=#{@account.id}, " \
                        "Type=#{result.category}, Confidence=#{result.confidence}"

      # Delete the media attachment
      @attachment.destroy if @config.auto_delete_violations?

      strike
    end

    def flag_for_review!(result)
      # Create a report for admin review
      Report.create!(
        account: Account.representative, # System account
        target_account: @account,
        status_ids: [@attachment.status_id].compact,
        comment: "[NSFW-Protect Auto-Flag] AI detected possible violation.\n" \
                 "Category: #{result.category}\n" \
                 "Confidence: #{(result.confidence * 100).round(1)}%\n" \
                 "Reason: #{result.reason}",
        category: :other
      )

      Rails.logger.info "[NSFW-Protect] Flagged for review: Account=#{@account.id}, " \
                        "Confidence=#{result.confidence}"
    end

    def calculate_severity(result)
      return 5 if result.csam? # Maximum severity
      return 4 if result.confidence >= 0.95
      return 3 if result.confidence >= 0.85
      return 2 if result.confidence >= 0.70

      1
    end

    def create_analysis_snapshot(result, strike: nil)
      NsfwAnalysisSnapshot.create_from_analysis(
        media_attachment: @attachment,
        account: @account,
        result: result,
        strike: strike
      )
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect] Failed to create analysis snapshot: #{e.message}"
      nil
    end

    def check_blocked_urls!
      return unless @attachment.status&.text.present?

      text = @attachment.status.text
      urls = extract_urls(text)

      urls.each do |url|
        check_result = Errordon::DomainBlocklistService.check_url(url)
        next unless check_result[:blocked]
        
        domain = URI.parse(url).host rescue url
        
        case check_result[:type]
        when :hard
          # Hard block: completely blocked, create strike and raise error
          handle_blocked_url!(url, check_result)
          raise ViolationError.new(
            check_result[:warning] || "Blocked domain: #{domain}",
            nil,
            violation_type: :blocked_url
          )
          
        when :soft
          # Soft block: flag as NSFW with warning, allow post but mark it
          handle_soft_blocked_url!(url, check_result)
          # Don't raise error, but mark the status as sensitive
        end
      end
    end

    def extract_urls(text)
      URI.extract(text, %w[http https])
    rescue StandardError
      []
    end

    def handle_blocked_url!(url, check_result)
      domain = URI.parse(url).host rescue url
      category = check_result[:category] || :blocked_domain

      strike = NsfwProtectStrike.create!(
        account: @account,
        status: @attachment.status,
        media_attachment: @attachment,
        strike_type: category == :porn ? :porn : :hate,
        severity: category == :neo_nazi ? 5 : 3,
        ip_address: @ip_address,
        ai_analysis_result: nil,
        ai_confidence: 1.0,
        ai_category: category.to_s.upcase,
        ai_reason: "Posted link to blocked domain (#{category}): #{domain}"
      )

      Rails.logger.warn "[NSFW-Protect] Hard blocked URL: Account=#{@account.id}, " \
                        "Domain=#{domain}, Category=#{category}"

      strike
    end

    def handle_soft_blocked_url!(url, check_result)
      domain = URI.parse(url).host rescue url
      status = @attachment.status
      
      # Mark status as sensitive (NSFW)
      status.update!(sensitive: true) if status.present?
      
      # Add spoiler text with warning if not already present
      if status.present? && status.spoiler_text.blank?
        warning = I18n.t(
          'errordon.blocklist.warnings.soft_block.fascism',
          default: check_result[:warning]
        )
        
        # Truncate for spoiler text (max 500 chars)
        spoiler = "⚠️ Enthält Link zu problematischer Quelle (#{check_result[:category]}). " \
                  "Bitte Screenshots statt Direktlinks teilen."
        
        status.update!(spoiler_text: spoiler)
      end
      
      # Log but don't create strike for soft blocks (just a warning)
      Rails.logger.info "[NSFW-Protect] Soft blocked URL flagged: Account=#{@account.id}, " \
                        "Domain=#{domain}, Category=#{check_result[:category]}"
      
      # Create audit log entry
      Errordon::AuditLogger.log(
        action: :soft_block_url,
        account_id: @account.id,
        details: {
          url: url,
          domain: domain,
          category: check_result[:category],
          status_id: status&.id
        }
      ) if defined?(Errordon::AuditLogger)
    end

    def extract_ip_from_request(request)
      return nil unless request

      request.remote_ip || request.ip
    rescue StandardError
      nil
    end

    def check_storage_quota!
      return unless @account

      file_size = @attachment.file_file_size.to_i
      quota_info = StorageQuotaService.quota_for(@account)

      unless StorageQuotaService.can_upload?(@account, file_size)
        message = I18n.t(
          'errordon.quota.exceeded',
          used: quota_info[:used_human],
          quota: quota_info[:quota_human],
          default: "Speicherplatz aufgebraucht (#{quota_info[:used_human]} von #{quota_info[:quota_human]}). " \
                   "Bitte lösche alte Medien oder teile nur Text/Links."
        )
        raise QuotaExceededError.new(message, quota_info)
      end
    end
  end
end
