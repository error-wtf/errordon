# frozen_string_literal: true

require 'net/http'
require 'json'
require 'open3'

module Errordon
  class OllamaContentAnalyzer
    SYSTEM_PROMPT = <<~PROMPT.freeze
      Du bist ein Content-Moderations-KI-System für eine deutsche Social-Media-Plattform.

      DEINE AUFGABEN:
      1. Erkennung von pornografischen Inhalten (Bilder/Videos)
      2. Erkennung von Hassrede und Volksverhetzung (§130 StGB)
      3. Erkennung von verfassungsfeindlichen Symbolen (§86a StGB)
      4. Erkennung von Kindesmissbrauch-Material (SOFORTIGE MELDUNG!)
      5. Erkennung von Gewaltverherrlichung

      ANALYSE-KATEGORIEN:
      - PORN: Explizite sexuelle Darstellungen, Nacktheit in sexuellem Kontext
      - HATE: Rassismus, Antisemitismus, Volksverhetzung, NS-Symbole
      - ILLEGAL: Gewalt, Terror-Propaganda
      - CSAM: Kindesmissbrauch (höchste Priorität!)
      - SAFE: Kein problematischer Inhalt erkannt
      - REVIEW: Unsicher, menschliche Überprüfung nötig

      WICHTIG - ERLAUBT:
      - Politische Diskussionen (Meinungsfreiheit Art. 5 GG)
      - Satire und Kunst
      - Nacktheit in künstlerischem/medizinischem Kontext
      - Kritische Berichterstattung

      ANTWORT NUR als JSON (keine andere Ausgabe):
      {"category":"KATEGORIE","confidence":0.0-1.0,"reason":"Kurze Begründung","law":"Falls relevant: §XY StGB"}
    PROMPT

    CATEGORIES = %w[PORN HATE ILLEGAL CSAM SAFE REVIEW].freeze

    class AnalysisResult
      attr_reader :category, :confidence, :reason, :law_reference, :raw_response

      def initialize(category:, confidence:, reason:, law_reference: nil, raw_response: nil)
        @category = category.to_s.upcase
        @confidence = confidence.to_f
        @reason = reason
        @law_reference = law_reference
        @raw_response = raw_response
      end

      def safe?
        category == 'SAFE'
      end

      def violation?
        !safe? && category != 'REVIEW'
      end

      def porn?
        category == 'PORN'
      end

      def hate?
        category == 'HATE'
      end

      def illegal?
        category == 'ILLEGAL'
      end

      def csam?
        category == 'CSAM'
      end

      def needs_review?
        category == 'REVIEW'
      end

      def high_confidence?
        confidence >= 0.85
      end

      def to_strike_type
        case category
        when 'PORN' then :porn
        when 'HATE' then :hate
        when 'ILLEGAL' then :illegal
        when 'CSAM' then :csam
        else :other
        end
      end

      def to_h
        {
          category: category,
          confidence: confidence,
          reason: reason,
          law_reference: law_reference
        }
      end
    end

    def initialize
      @config = NsfwProtectConfig.current
      @endpoint = @config.ollama_endpoint
      @vision_model = @config.ollama_vision_model
      @text_model = @config.ollama_text_model
    end

    def analyze_image(image_path_or_url)
      return safe_result('NSFW-Protect disabled') unless @config.enabled?
      return safe_result('Ollama not configured') unless @config.ollama_configured?

      image_data = load_image_as_base64(image_path_or_url)
      return safe_result('Could not load image') if image_data.nil?

      prompt = "Analysiere dieses Bild auf verbotene Inhalte. #{SYSTEM_PROMPT}"

      response = call_ollama_vision(prompt, image_data)
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect] Image analysis error: #{e.message}"
      AnalysisResult.new(category: 'REVIEW', confidence: 0.0, reason: "Analysis error: #{e.message}")
    end

    def analyze_video(video_path, frame_count: 5)
      return safe_result('NSFW-Protect disabled') unless @config.enabled?
      return safe_result('Ollama not configured') unless @config.ollama_configured?

      frames = extract_video_frames(video_path, frame_count)
      return safe_result('Could not extract frames') if frames.empty?

      results = frames.map { |frame| analyze_image(frame) }

      # Clean up temporary frame files
      frames.each { |f| File.delete(f) if File.exist?(f) }

      # If ANY frame is flagged, the video is flagged
      violation = results.find(&:violation?)
      return violation if violation

      review = results.find(&:needs_review?)
      return review if review

      safe_result('All frames safe')
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect] Video analysis error: #{e.message}"
      AnalysisResult.new(category: 'REVIEW', confidence: 0.0, reason: "Analysis error: #{e.message}")
    end

    def analyze_text(text)
      return safe_result('NSFW-Protect disabled') unless @config.enabled?
      return safe_result('Ollama not configured') unless @config.ollama_configured?
      return safe_result('Empty text') if text.blank?

      prompt = <<~TEXT
        Analysiere folgenden Text auf Hassrede, Volksverhetzung oder illegale Inhalte:

        ---
        #{text.truncate(2000)}
        ---

        #{SYSTEM_PROMPT}
      TEXT

      response = call_ollama_text(prompt)
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect] Text analysis error: #{e.message}"
      AnalysisResult.new(category: 'REVIEW', confidence: 0.0, reason: "Analysis error: #{e.message}")
    end

    private

    def safe_result(reason)
      AnalysisResult.new(category: 'SAFE', confidence: 1.0, reason: reason)
    end

    def load_image_as_base64(path_or_url)
      if path_or_url.start_with?('http')
        response = HTTP.timeout(30).get(path_or_url)
        return nil unless response.status.success?

        Base64.strict_encode64(response.body.to_s)
      elsif File.exist?(path_or_url)
        Base64.strict_encode64(File.read(path_or_url))
      end
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect] Failed to load image: #{e.message}"
      nil
    end

    def extract_video_frames(video_path, frame_count)
      return [] unless File.exist?(video_path)

      # Get video duration
      duration_cmd = "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \"#{video_path}\""
      duration, status = Open3.capture2(duration_cmd)
      return [] unless status.success?

      duration = duration.to_f
      return [] if duration <= 0

      frames = []
      frame_count.times do |i|
        timestamp = (duration * i / frame_count).round(2)
        output_path = Rails.root.join('tmp', "nsfw_frame_#{SecureRandom.hex(8)}.jpg").to_s

        cmd = "ffmpeg -ss #{timestamp} -i \"#{video_path}\" -vframes 1 -q:v 2 \"#{output_path}\" -y 2>/dev/null"
        system(cmd)

        frames << output_path if File.exist?(output_path)
      end

      frames
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect] Frame extraction error: #{e.message}"
      []
    end

    def call_ollama_vision(prompt, image_base64)
      uri = URI("#{@endpoint}/api/generate")

      request_body = {
        model: @vision_model,
        prompt: prompt,
        images: [image_base64],
        stream: false,
        options: {
          temperature: 0.1,
          num_predict: 200
        }
      }

      make_ollama_request(uri, request_body)
    end

    def call_ollama_text(prompt)
      uri = URI("#{@endpoint}/api/generate")

      request_body = {
        model: @text_model,
        prompt: prompt,
        stream: false,
        options: {
          temperature: 0.1,
          num_predict: 200
        }
      }

      make_ollama_request(uri, request_body)
    end

    def make_ollama_request(uri, body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = 120
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "[NSFW-Protect] Ollama API error: #{response.code} - #{response.body}"
        return nil
      end

      JSON.parse(response.body)['response']
    rescue StandardError => e
      Rails.logger.error "[NSFW-Protect] Ollama request failed: #{e.message}"
      nil
    end

    def parse_response(response_text)
      return AnalysisResult.new(category: 'REVIEW', confidence: 0.0, reason: 'No response from AI') if response_text.blank?

      # Try to extract JSON from response
      json_match = response_text.match(/\{[^}]+\}/m)
      return AnalysisResult.new(category: 'REVIEW', confidence: 0.5, reason: 'Could not parse AI response', raw_response: response_text) unless json_match

      data = JSON.parse(json_match[0])

      category = data['category'].to_s.upcase
      category = 'REVIEW' unless CATEGORIES.include?(category)

      AnalysisResult.new(
        category: category,
        confidence: data['confidence'].to_f.clamp(0.0, 1.0),
        reason: data['reason'].to_s,
        law_reference: data['law'],
        raw_response: response_text
      )
    rescue JSON::ParserError => e
      Rails.logger.error "[NSFW-Protect] JSON parse error: #{e.message}"
      AnalysisResult.new(category: 'REVIEW', confidence: 0.5, reason: 'JSON parse error', raw_response: response_text)
    end
  end
end
