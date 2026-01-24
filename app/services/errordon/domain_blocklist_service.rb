# frozen_string_literal: true

require 'net/http'
require 'fileutils'
require 'yaml'

module Errordon
  class DomainBlocklistService
    # File paths
    PORN_BLOCKLIST_PATH = Rails.root.join('config', 'errordon', 'porn_domain_blocklist.txt')
    FASCISM_BLOCKLIST_PATH = Rails.root.join('config', 'errordon', 'fascism_blocklist.yml')
    
    # Cache keys
    PORN_CACHE_KEY = 'errordon:porn_blocklist'
    FASCISM_HARD_CACHE_KEY = 'errordon:fascism_hard_blocklist'
    FASCISM_SOFT_CACHE_KEY = 'errordon:fascism_soft_blocklist'
    CACHE_TTL = 1.hour

    # Block types
    BLOCK_TYPES = {
      hard: :hard,      # Completely blocked, no override
      soft: :soft,      # Warning + NSFW toggle
      none: :none       # Not blocked
    }.freeze

    # Categories
    CATEGORIES = {
      porn: :porn,
      hate: :hate,
      fascism: :fascism,
      neo_nazi: :neo_nazi,
      conspiracy: :conspiracy
    }.freeze

    # Known blocklist sources for porn (multiple for redundancy)
    BLOCKLIST_SOURCES = [
      {
        name: 'StevenBlack Porn',
        url: 'https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts',
        format: :hosts
      },
      {
        name: 'Sinfonietta Porn',
        url: 'https://raw.githubusercontent.com/Sinfonietta/hostfiles/master/pornography-hosts',
        format: :hosts
      },
      {
        name: 'oisd nsfw',
        url: 'https://nsfw.oisd.nl/domainswild',
        format: :domains
      }
    ].freeze

    # Hardcoded critical porn domains (always blocked)
    HARDCODED_PORN_DOMAINS = %w[
      pornhub.com xvideos.com xnxx.com xhamster.com redtube.com
      youporn.com tube8.com spankbang.com chaturbate.com
      onlyfans.com fansly.com livejasmin.com stripchat.com
      cam4.com bongacams.com myfreecams.com camsoda.com
      brazzers.com bangbros.com realitykings.com naughtyamerica.com
      porntrex.com eporner.com thumbzilla.com pornone.com
      hentaihaven.xxx hanime.tv nhentai.net hentai-foundry.com
      rule34.xxx e621.net gelbooru.com danbooru.donmai.us
    ].freeze

    # Legacy alias
    HARDCODED_DOMAINS = HARDCODED_PORN_DOMAINS

    class << self
      # =======================================================================
      # MAIN CHECK METHODS
      # =======================================================================
      
      # Check domain and return detailed result
      # Returns: { blocked: bool, type: :hard/:soft/:none, category: symbol, warning: string }
      def check_domain(domain)
        domain = normalize_domain(domain)
        
        # 1. Check porn (always hard block)
        if porn_blocked?(domain)
          return {
            blocked: true,
            type: :hard,
            category: :porn,
            warning: warning_message(:hard, :porn)
          }
        end
        
        # 2. Check fascism hard block (neo-nazi, holocaust denial, etc.)
        if fascism_hard_blocked?(domain)
          return {
            blocked: true,
            type: :hard,
            category: :neo_nazi,
            warning: warning_message(:hard, :fascism)
          }
        end
        
        # 3. Check fascism soft block (far-right parties, media)
        if fascism_soft_blocked?(domain)
          return {
            blocked: true,
            type: :soft,
            category: :fascism,
            warning: warning_message(:soft, :fascism),
            can_override: true
          }
        end
        
        # Not blocked
        { blocked: false, type: :none, category: nil }
      end

      # Check URL and return detailed result
      def check_url(url)
        uri = URI.parse(url)
        check_domain(uri.host)
      rescue URI::InvalidURIError
        { blocked: false, type: :none, category: nil }
      end

      # Simple boolean check (backwards compatible)
      def blocked?(domain)
        result = check_domain(domain)
        result[:blocked] && result[:type] == :hard
      end

      # Check if soft-blocked (warning but can override)
      def soft_blocked?(domain)
        result = check_domain(domain)
        result[:blocked] && result[:type] == :soft
      end

      # =======================================================================
      # CATEGORY-SPECIFIC CHECKS
      # =======================================================================

      def porn_blocked?(domain)
        domain = normalize_domain(domain)
        return true if HARDCODED_PORN_DOMAINS.any? { |d| domain.end_with?(d) }
        
        blocklist = load_porn_blocklist
        blocklist.any? { |d| domain.end_with?(d) }
      end

      def fascism_hard_blocked?(domain)
        domain = normalize_domain(domain)
        blocklist = load_fascism_hard_blocklist
        blocklist.any? { |d| domain.end_with?(d) }
      end

      def fascism_soft_blocked?(domain)
        domain = normalize_domain(domain)
        blocklist = load_fascism_soft_blocklist
        blocklist.any? { |d| domain.end_with?(d) }
      end

      # =======================================================================
      # LOAD BLOCKLISTS
      # =======================================================================

      def load_blocklist
        load_porn_blocklist
      end

      def load_porn_blocklist
        cached = Rails.cache.read(PORN_CACHE_KEY)
        return cached if cached.present?

        if File.exist?(PORN_BLOCKLIST_PATH)
          domains = File.readlines(PORN_BLOCKLIST_PATH).map(&:strip).reject(&:blank?)
          Rails.cache.write(PORN_CACHE_KEY, domains, expires_in: CACHE_TTL)
          return domains
        end

        HARDCODED_PORN_DOMAINS
      end

      def load_fascism_hard_blocklist
        cached = Rails.cache.read(FASCISM_HARD_CACHE_KEY)
        return cached if cached.present?

        domains = extract_fascism_domains(:hard_block)
        Rails.cache.write(FASCISM_HARD_CACHE_KEY, domains, expires_in: CACHE_TTL)
        domains
      end

      def load_fascism_soft_blocklist
        cached = Rails.cache.read(FASCISM_SOFT_CACHE_KEY)
        return cached if cached.present?

        domains = extract_fascism_domains(:soft_block)
        Rails.cache.write(FASCISM_SOFT_CACHE_KEY, domains, expires_in: CACHE_TTL)
        domains
      end

      def extract_fascism_domains(block_type)
        return [] unless File.exist?(FASCISM_BLOCKLIST_PATH)
        
        config = YAML.load_file(FASCISM_BLOCKLIST_PATH)
        domains = []
        
        block_data = config[block_type.to_s]
        return [] unless block_data.is_a?(Hash)
        
        extract_domains_recursive(block_data, domains)
        domains.uniq
      end

      def extract_domains_recursive(data, domains)
        case data
        when Array
          data.each { |item| extract_domains_recursive(item, domains) }
        when Hash
          data.each_value { |value| extract_domains_recursive(value, domains) }
        when String
          domains << data.strip if data.include?('.')
        end
      end

      # =======================================================================
      # UPDATE BLOCKLISTS
      # =======================================================================

      def update_blocklist!
        Rails.logger.info "[NSFW-Protect] Starting blocklist update..."
        
        all_domains = Set.new(HARDCODED_PORN_DOMAINS)
        
        BLOCKLIST_SOURCES.each do |source|
          begin
            domains = fetch_from_source(source)
            all_domains.merge(domains)
            Rails.logger.info "[NSFW-Protect] Fetched #{domains.size} domains from #{source[:name]}"
          rescue StandardError => e
            Rails.logger.error "[NSFW-Protect] Failed to fetch from #{source[:name]}: #{e.message}"
          end
        end

        FileUtils.mkdir_p(File.dirname(PORN_BLOCKLIST_PATH))
        File.write(PORN_BLOCKLIST_PATH, all_domains.to_a.sort.join("\n"))
        
        # Clear all caches
        Rails.cache.delete(PORN_CACHE_KEY)
        Rails.cache.delete(FASCISM_HARD_CACHE_KEY)
        Rails.cache.delete(FASCISM_SOFT_CACHE_KEY)

        Rails.logger.info "[NSFW-Protect] Blocklist updated: #{all_domains.size} porn domains"
        
        { success: true, count: all_domains.size }
      rescue StandardError => e
        Rails.logger.error "[NSFW-Protect] Blocklist update failed: #{e.message}"
        { success: false, error: e.message }
      end

      # =======================================================================
      # STATISTICS
      # =======================================================================

      def stats
        porn_list = load_porn_blocklist
        fascism_hard = load_fascism_hard_blocklist
        fascism_soft = load_fascism_soft_blocklist
        
        {
          porn: {
            total: porn_list.size,
            hardcoded: HARDCODED_PORN_DOMAINS.size,
            file_exists: File.exist?(PORN_BLOCKLIST_PATH),
            last_updated: File.exist?(PORN_BLOCKLIST_PATH) ? File.mtime(PORN_BLOCKLIST_PATH) : nil
          },
          fascism: {
            hard_block: fascism_hard.size,
            soft_block: fascism_soft.size,
            total: fascism_hard.size + fascism_soft.size,
            file_exists: File.exist?(FASCISM_BLOCKLIST_PATH)
          },
          total_domains: porn_list.size + fascism_hard.size + fascism_soft.size,
          sources: BLOCKLIST_SOURCES.map { |s| s[:name] }
        }
      end

      # =======================================================================
      # WARNING MESSAGES
      # =======================================================================

      def warning_message(block_type, category, locale = :de)
        messages = {
          de: {
            hard: {
              porn: "🚫 Pornografische Inhalte sind auf dieser Instanz nicht erlaubt.",
              fascism: "🚫 Diese URL verweist auf eine Webseite mit illegalem Inhalt (Neonazi-Propaganda, Holocaust-Leugnung, Terrorismus). Das Teilen solcher Links ist nicht erlaubt."
            },
            soft: {
              fascism: "⚠️ Diese URL verweist auf eine Webseite, die Hass, Faschismus oder rechtsextreme Inhalte verbreitet.\n\nWir möchten diesen Seiten keinen Traffic geben.\n\n📸 Wenn du über diese Seite berichten möchtest, teile bitte einen Screenshot statt eines Direktlinks.\n\nDu kannst den Link manuell einblenden, aber er wird als NSFW markiert."
            }
          },
          en: {
            hard: {
              porn: "🚫 Pornographic content is not allowed on this instance.",
              fascism: "🚫 This URL points to a website with illegal content (Neo-Nazi propaganda, Holocaust denial, terrorism). Sharing such links is not allowed."
            },
            soft: {
              fascism: "⚠️ This URL points to a website that spreads hate, fascism, or far-right extremist content.\n\nWe don't want to give these sites traffic.\n\n📸 If you want to report about this site, please share a screenshot instead of a direct link.\n\nYou can manually reveal the link, but it will be marked as NSFW."
            }
          }
        }
        
        messages.dig(locale, block_type, category) || messages.dig(:en, block_type, category) || "Blocked content"
      end

      # =======================================================================
      # WHITELIST CHECK
      # =======================================================================

      def whitelisted?(domain)
        return false unless File.exist?(FASCISM_BLOCKLIST_PATH)
        
        config = YAML.load_file(FASCISM_BLOCKLIST_PATH)
        whitelist = config.dig('whitelist', 'journalism') || []
        
        domain = normalize_domain(domain)
        whitelist.any? { |d| domain.end_with?(d) }
      end

      private

      def normalize_domain(domain)
        domain.to_s.downcase.gsub(/^www\./, '')
      end

      def fetch_from_source(source)
        uri = URI(source[:url])
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = 30
        http.open_timeout = 10

        response = http.get(uri.request_uri)
        
        unless response.is_a?(Net::HTTPSuccess)
          raise "HTTP #{response.code}"
        end

        parse_response(response.body, source[:format])
      end

      def parse_response(body, format)
        case format
        when :hosts
          parse_hosts_format(body)
        when :domains
          parse_domains_format(body)
        else
          []
        end
      end

      def parse_hosts_format(content)
        domains = []
        content.each_line do |line|
          line = line.strip
          next if line.blank? || line.start_with?('#')
          
          parts = line.split(/\s+/)
          next unless parts.size >= 2
          
          domain = parts[1]
          next if domain == 'localhost' || domain.start_with?('local')
          
          domains << domain
        end
        domains
      end

      def parse_domains_format(content)
        domains = []
        content.each_line do |line|
          line = line.strip.gsub(/^\*\./, '')
          next if line.blank? || line.start_with?('#')
          domains << line
        end
        domains
      end
    end
  end
end
