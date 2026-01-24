# frozen_string_literal: true

module Errordon
  class MediaUploadChecker
    class ViolationError < StandardError
      attr_reader :analysis_result

      def initialize(message, analysis_result)
        super(message)
        @analysis_result = analysis_result
      end
    end

    def initialize(media_attachment, ip_address: nil)
      @attachment = media_attachment
      @account = media_attachment.account
      @ip_address = ip_address
      @config = NsfwProtectConfig.current
      @analyzer = OllamaContentAnalyzer.new
    end

    def call
      return true unless should_check?

      # Check if account is frozen
      raise_if_frozen!

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

      true
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
  end
end
