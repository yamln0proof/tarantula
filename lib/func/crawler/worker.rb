# frozen_string_literal: true

require "set"
require "uri"
require_relative "fetcher"
require_relative "processor"

module Worker
  class Crawler
    DOMAIN_PATTERN = /\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/i
    DEFAULT_MAX_PAGES = 500

    def initialize(domains, fixture_root:, max_pages: DEFAULT_MAX_PAGES)
      @domains = normalize_domains(domains)
      @max_pages = Integer(max_pages)
      raise ArgumentError, "max_pages must be positive" unless @max_pages.positive?

      @fetcher = Tarantula::Fetcher.new(fixture_root: fixture_root, domains: @domains)
      @processor = Tarantula::Processor.new(domains: @domains)
    end

    def run
      queue = @domains.map { |domain| "https://#{domain}/" }
      queued = queue.to_set
      visited = Set.new
      pages = []
      files = {}
      missing = []
      missing_urls = Set.new

      until queue.empty? || pages.length >= @max_pages
        url = queue.shift
        next unless visited.add?(url)

        result = @fetcher.fetch(url)
        case result[:kind]
        when :page
          links = @processor.process(result[:body], url)
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
        pages: pages,
        files: files.values,
        missing: missing,
        visited: visited.to_a,
        truncated: !queue.empty?
      }
    end

    private

    def normalize_domains(domains)
      normalized = domains.map { |domain| domain.to_s.strip.downcase }.reject(&:empty?).uniq
      raise ArgumentError, "Provide at least one domain" if normalized.empty?

      invalid = normalized.reject { |domain| DOMAIN_PATTERN.match?(domain) && !domain.include?("..") }
      raise ArgumentError, "Invalid domain name: #{invalid.first}" unless invalid.empty?

      normalized.freeze
    end
  end
end
