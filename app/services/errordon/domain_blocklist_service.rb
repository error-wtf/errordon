# frozen_string_literal: true

require 'net/http'
require 'fileutils'

module Errordon
  class DomainBlocklistService
    BLOCKLIST_PATH = Rails.root.join('config', 'errordon', 'porn_domain_blocklist.txt')
    BLOCKLIST_CACHE_KEY = 'errordon:porn_blocklist'
    CACHE_TTL = 1.hour

    # Known blocklist sources (multiple for redundancy)
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

    # Hardcoded critical domains (always blocked)
    HARDCODED_DOMAINS = %w[
      pornhub.com xvideos.com xnxx.com xhamster.com redtube.com
      youporn.com tube8.com spankbang.com chaturbate.com
      onlyfans.com fansly.com livejasmin.com stripchat.com
      cam4.com bongacams.com myfreecams.com camsoda.com
      brazzers.com bangbros.com realitykings.com naughtyamerica.com
      porntrex.com eporner.com thumbzilla.com pornone.com
      hentaihaven.xxx hanime.tv nhentai.net hentai-foundry.com
      rule34.xxx e621.net gelbooru.com danbooru.donmai.us
      4chan.org 8kun.top kiwifarms.net
    ].freeze

    class << self
      def blocked?(domain)
        return true if HARDCODED_DOMAINS.any? { |d| domain.end_with?(d) }
        
        blocklist = load_blocklist
        blocklist.any? { |d| domain.end_with?(d) }
      end

      def check_url(url)
        uri = URI.parse(url)
        blocked?(uri.host)
      rescue URI::InvalidURIError
        false
      end

      def load_blocklist
        # Try cache first
        cached = Rails.cache.read(BLOCKLIST_CACHE_KEY)
        return cached if cached.present?

        # Load from file
        if File.exist?(BLOCKLIST_PATH)
          domains = File.readlines(BLOCKLIST_PATH).map(&:strip).reject(&:blank?)
          Rails.cache.write(BLOCKLIST_CACHE_KEY, domains, expires_in: CACHE_TTL)
          return domains
        end

        # Fallback to hardcoded
        HARDCODED_DOMAINS
      end

      def update_blocklist!
        Rails.logger.info "[NSFW-Protect] Starting blocklist update..."
        
        all_domains = Set.new(HARDCODED_DOMAINS)
        
        BLOCKLIST_SOURCES.each do |source|
          begin
            domains = fetch_from_source(source)
            all_domains.merge(domains)
            Rails.logger.info "[NSFW-Protect] Fetched #{domains.size} domains from #{source[:name]}"
          rescue StandardError => e
            Rails.logger.error "[NSFW-Protect] Failed to fetch from #{source[:name]}: #{e.message}"
          end
        end

        # Write to file
        FileUtils.mkdir_p(File.dirname(BLOCKLIST_PATH))
        File.write(BLOCKLIST_PATH, all_domains.to_a.sort.join("\n"))
        
        # Clear cache
        Rails.cache.delete(BLOCKLIST_CACHE_KEY)

        Rails.logger.info "[NSFW-Protect] Blocklist updated: #{all_domains.size} total domains"
        
        { success: true, count: all_domains.size }
      rescue StandardError => e
        Rails.logger.error "[NSFW-Protect] Blocklist update failed: #{e.message}"
        { success: false, error: e.message }
      end

      def stats
        blocklist = load_blocklist
        {
          total_domains: blocklist.size,
          hardcoded_count: HARDCODED_DOMAINS.size,
          file_exists: File.exist?(BLOCKLIST_PATH),
          last_updated: File.exist?(BLOCKLIST_PATH) ? File.mtime(BLOCKLIST_PATH) : nil,
          sources: BLOCKLIST_SOURCES.map { |s| s[:name] }
        }
      end

      private

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
          
          # Format: 0.0.0.0 domain.com or 127.0.0.1 domain.com
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
          line = line.strip.gsub(/^\*\./, '')  # Remove wildcard prefix
          next if line.blank? || line.start_with?('#')
          domains << line
        end
        domains
      end
    end
  end
end
