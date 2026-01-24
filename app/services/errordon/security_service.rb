# frozen_string_literal: true

module Errordon
  class SecurityService
    DANGEROUS_MIME_TYPES = %w[
      application/x-executable
      application/x-sharedlib
      application/x-shellscript
      application/x-msdos-program
      application/x-msdownload
      application/x-dosexec
      application/bat
      application/x-bat
      application/cmd
      application/x-cmd
      text/x-shellscript
      text/x-script.python
      text/x-python
      application/javascript
      text/javascript
      application/x-httpd-php
      application/php
      text/x-php
    ].freeze

    ALLOWED_VIDEO_CODECS = %w[h264 hevc vp8 vp9 av1 mpeg4 theora].freeze
    ALLOWED_AUDIO_CODECS = %w[aac mp3 opus vorbis flac wav pcm_s16le].freeze

    MAX_FILENAME_LENGTH = 255
    SUSPICIOUS_PATTERNS = [
      /\.\./,                    # Path traversal
      /[<>:"|?*]/,               # Invalid chars
      /\x00/,                    # Null bytes
      /[\r\n]/,                  # Newlines in filename
      /%[0-9a-fA-F]{2}/,         # URL encoded
      /\.(exe|bat|cmd|sh|ps1|vbs|js|jar|msi|dll|scr)$/i
    ].freeze

    class SecurityViolationError < StandardError; end
    class MaliciousFileError < SecurityViolationError; end
    class PathTraversalError < SecurityViolationError; end
    class InvalidFileTypeError < SecurityViolationError; end

    def initialize(file, options = {})
      @file = file
      @options = options
      @violations = []
    end

    def validate!
      validate_filename!
      validate_mime_type!
      validate_file_content!
      validate_file_size!

      log_security_check

      raise MaliciousFileError, @violations.join('; ') if @violations.any?

      true
    end

    def self.sanitize_filename(filename)
      return 'unnamed' if filename.blank?

      # Remove path components
      sanitized = File.basename(filename.to_s)

      # Remove null bytes and control characters
      sanitized = sanitized.gsub(/[\x00-\x1f\x7f]/, '')

      # Remove suspicious patterns
      sanitized = sanitized.gsub(/\.\./, '_')
      sanitized = sanitized.gsub(/[<>:"|?*\\\/]/, '_')

      # Limit length
      if sanitized.length > MAX_FILENAME_LENGTH
        ext = File.extname(sanitized)
        base = File.basename(sanitized, ext)
        sanitized = "#{base[0...(MAX_FILENAME_LENGTH - ext.length - 1)]}#{ext}"
      end

      # Ensure we have a valid filename
      sanitized = 'unnamed' if sanitized.blank? || sanitized == '.'

      sanitized
    end

    def self.safe_path?(path, base_dir)
      return false if path.blank? || base_dir.blank?

      expanded_path = File.expand_path(path)
      expanded_base = File.expand_path(base_dir)

      expanded_path.start_with?(expanded_base)
    end

    private

    def validate_filename!
      return unless @file.respond_to?(:original_filename)

      filename = @file.original_filename.to_s

      SUSPICIOUS_PATTERNS.each do |pattern|
        if filename.match?(pattern)
          @violations << "Suspicious filename pattern detected: #{pattern.inspect}"
        end
      end

      if filename.length > MAX_FILENAME_LENGTH
        @violations << "Filename too long: #{filename.length} > #{MAX_FILENAME_LENGTH}"
      end
    end

    def validate_mime_type!
      return unless @file.respond_to?(:content_type)

      content_type = @file.content_type.to_s.downcase

      if DANGEROUS_MIME_TYPES.include?(content_type)
        @violations << "Dangerous MIME type: #{content_type}"
      end

      # Verify MIME type matches file extension
      if @file.respond_to?(:original_filename)
        expected_types = Marcel::MimeType.for(name: @file.original_filename)
        if expected_types.present? && !content_type.start_with?(expected_types.split('/').first)
          @violations << "MIME type mismatch: #{content_type} vs expected #{expected_types}"
        end
      end
    end

    def validate_file_content!
      return unless @file.respond_to?(:read) && @file.respond_to?(:rewind)

      # Read first bytes for magic number check
      @file.rewind
      header = @file.read(8192)
      @file.rewind

      return if header.nil?

      # Check for executable signatures
      check_executable_signatures(header)

      # Check for embedded scripts in media files
      check_embedded_scripts(header)

      # Check for polyglot files
      check_polyglot_patterns(header)
    end

    def check_executable_signatures(header)
      signatures = {
        'MZ' => 'Windows executable',
        "\x7fELF" => 'Linux executable',
        '#!' => 'Shell script',
        '<?php' => 'PHP script',
        '<%' => 'ASP script',
        '<script' => 'JavaScript',
        'PK' => 'ZIP/JAR archive'  # Could contain executables
      }

      signatures.each do |sig, desc|
        if header.start_with?(sig) && !allowed_archive?(header, sig)
          @violations << "Executable signature detected: #{desc}"
        end
      end
    end

    def allowed_archive?(header, sig)
      # Allow ZIP only if it's a legitimate media container
      return false unless sig == 'PK'

      # Check if it's a known media container that uses ZIP
      header.include?('mimetype') && header.include?('application/epub')
    end

    def check_embedded_scripts(header)
      script_patterns = [
        /<script[^>]*>/i,
        /javascript:/i,
        /vbscript:/i,
        /on\w+\s*=/i,  # Event handlers
        /data:text\/html/i
      ]

      script_patterns.each do |pattern|
        if header.match?(pattern)
          @violations << "Embedded script pattern detected"
          break
        end
      end
    end

    def check_polyglot_patterns(header)
      # Check for GIFAR (GIF + JAR) attacks
      if header.start_with?('GIF8') && header.include?('PK')
        @violations << "Potential polyglot file detected (GIFAR)"
      end

      # Check for image with embedded HTML
      if header.match?(/\A(GIF8|\x89PNG|\xff\xd8\xff)/) && header.match?(/<html/i)
        @violations << "Potential polyglot file detected (image+HTML)"
      end
    end

    def validate_file_size!
      return unless @file.respond_to?(:size)

      max_size = @options[:max_size] || 250.megabytes

      if @file.size > max_size
        @violations << "File too large: #{@file.size} > #{max_size}"
      end

      if @file.size.zero?
        @violations << "Empty file"
      end
    end

    def log_security_check
      severity = @violations.any? ? :warn : :info
      details = {
        filename: @file.try(:original_filename),
        content_type: @file.try(:content_type),
        size: @file.try(:size),
        violations: @violations,
        ip: @options[:ip],
        user_id: @options[:user_id]
      }

      if @violations.any?
        Rails.logger.warn "[Errordon::Security] File rejected: #{details.to_json}"
        Errordon::AuditLogger.log_security_event(:file_rejected, details)
      else
        Rails.logger.info "[Errordon::Security] File accepted: #{details[:filename]}"
      end
    end
  end
end
