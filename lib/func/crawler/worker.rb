# frozen_string_literal: true

require "set"
require "uri"
require_relative "fetcher"
require_relative "processor"
require_relative "../../../models/captcha/captcha_detector"

module Worker
  class Crawler
    DOMAIN_PATTERN = /\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/i
    DEFAULT_MAX_PAGES = 500

    #Initialization
    def initialize(domains = nil, domains_file: nil, max_pages: DEFAULT_MAX_PAGES)
      @domains = normalize_domains(domain_source(domains, domains_file))
      @max_pages = Integer(max_pages)
      raise ArgumentError, "max_pages must be positive" unless @max_pages.positive?

      @fetcher = Tarantula::Fetcher.new(domains: @domains)
      @processor = Tarantula::Processor.new(domains: @domains)
      @captcha_detector = Tarantula::CaptchaDetector.new
    end

    def run
      queue = @domains.map { |domain| "https://#{domain}/" }
      queued = queue.to_set
      visited = Set.new
      pages = []
      files = {}
      missing = []
      missing_urls = Set.new
      captchas = []

      until queue.empty? || pages.length >= @max_pages
        url = queue.shift
        next unless visited.add?(url)

        result = @fetcher.fetch(url)
        case result[:kind]
        when :page
          detection = @captcha_detector.detect(result[:body])
          if detection[:detected]
            captchas << {
              url: result[:url],
              confidence: detection[:confidence],
              signals: detection[:signals]
            }
            break
          end

          links = @processor.process(result[:body], result[:url])
          pages << result.reject { |key, _| key == :body }.merge(links: links)

          links.each do |link|
            if link[:kind] == :page
              queue << link[:url] if queued.add?(link[:url])
            else
              next if files.key?(link[:url]) || missing_urls.include?(link[:url])

              file = @fetcher.fetch(link[:url])
              if file[:kind] == :file
                files[file[:url]] ||= file
              elsif file[:kind] == :missing
                missing << file
                missing_urls.add?(file[:url])
              elsif queued.add?(file[:url])
                queue << file[:url]
              end
            end
          end
        when :file
          files[result[:url]] ||= result
        when :missing
          missing << result
          missing_urls.add?(result[:url])
        end
      end

      {
        domains: @domains,
        pages: pages,
        files: files.values,
        missing: missing,
        captchas: captchas,
        visited: visited.to_a,
        stopped_for_captcha: !captchas.empty?,
        truncated: !queue.empty? && pages.length >= @max_pages
      }
    end

    private

    #Notmalization
    def normalize_domains(domains)
      normalized = Array(domains).flat_map do |entry|
        entry.to_s.lines.flat_map { |line| line.split("#", 2).first.to_s.split(/[,\s]+/) }
      end.map { |domain| domain.strip.downcase }.reject(&:empty?).uniq
      raise ArgumentError, "Provide at least one domain" if normalized.empty?

      invalid = normalized.reject { |domain| DOMAIN_PATTERN.match?(domain) && !domain.include?("..") }
      raise ArgumentError, "Invalid domain name: #{invalid.first}" unless invalid.empty?

      normalized.freeze
    end

    #Method for user input as a file or domain string
    def domain_source(domains, domains_file)
      if domains && domains_file
        raise ArgumentError, "Provide domains directly or with domains_file, not both"
      end

      return domains unless domains_file

      File.read(domains_file)
    end
  end
end
