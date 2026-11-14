#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true

#Libraries
require "set"
require "uri"
require_relative "fetcher"
require_relative "processor"
require_relative "../../../models/captcha/captcha_detector"
require_relative "../../config/settings"


module Worker
  class Crawler
    DOMAIN_PATTERN = /\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/i

    #Initialization
    def initialize(domains = nil, domains_file: nil, settings: Tarantula::Config::Settings.new, on_update: nil)
      @domains = normalize_domains(domain_source(domains, domains_file))
      @settings = settings
      @on_update = on_update
      @stop_mutex = Mutex.new
      @stop_requested = false

      @fetcher = Tarantula::Fetcher.new(
        domains: @domains,
        max_html_bytes: @settings[:max_html_bytes],
        open_timeout: @settings[:open_timeout],
        read_timeout: @settings[:read_timeout],
        max_redirects: @settings[:max_redirects],
        requests_per_minute: @settings[:requests_per_minute],
        custom_header: @settings[:custom_header],
        stop_requested: method(:stop_requested?)
      )
      @processor = Tarantula::Processor.new(domains: @domains)
      @captcha_detector = Tarantula::CaptchaDetector.new(threshold: @settings[:captcha_threshold])
    end

    def stop
      @stop_mutex.synchronize { @stop_requested = true }
    end

    #Main Method
    def run
      queue = @domains.map { |domain| "https://#{domain}/" }
      queued = queue.to_set
      visited = Set.new
      pages = []
      files = {}
      missing = []
      missing_urls = Set.new
      captchas = []
      errors = []
      failed_urls = Set.new

      until queue.empty? || stop_requested?
        url = queue.shift
        next unless visited.add?(url)

        begin
          result = @fetcher.fetch(url)
        rescue IOError, ArgumentError, URI::Error, SystemCallError, Timeout::Error,
               Net::HTTPError, OpenSSL::SSL::SSLError => error
          record_crawl_error(errors, failed_urls, url, error)
          next
        end
        next if result[:kind] == :stopped

        next if result[:url] != url && !visited.add?(result[:url])

        case result[:kind]
        when :page
          notify_update(:page, result)
          begin
            detection = @captcha_detector.detect(result[:body])
          rescue ArgumentError, EncodingError, Nokogiri::XML::SyntaxError => error
            record_crawl_error(errors, failed_urls, result[:url], error)
            next
          end

          #Captcha block
          if detection[:detected]
            captchas << {
              url: result[:url],
              confidence: detection[:confidence],
              signals: detection[:signals]
            }
            #TODO: Captcha solving Code
            
          end
          
          #Main crawling logic(fetching, processing)
          begin
            links = extract_and_enqueue_links(result, queue, queued)
          rescue ArgumentError, EncodingError, Nokogiri::XML::SyntaxError, URI::Error => error
            record_crawl_error(errors, failed_urls, result[:url], error)
            next
          end
          links.each { |link| notify_update(:link, link) }
          pages << result.reject { |key, _| key == :body }.merge(links: links)

          links.each do |link|
            break if stop_requested?
            next if link[:kind] == :page
            next if files.key?(link[:url]) || missing_urls.include?(link[:url]) || failed_urls.include?(link[:url])

            begin
              file = @fetcher.fetch(link[:url])
            rescue IOError, ArgumentError, URI::Error, SystemCallError, Timeout::Error,
                   Net::HTTPError, OpenSSL::SSL::SSLError => error
              record_crawl_error(errors, failed_urls, link[:url], error)
              next
            end
            next if file[:kind] == :stopped

            if file[:kind] == :file
              files[file[:url]] ||= file
              notify_update(:file, file)
            elsif file[:kind] == :missing
              missing << file
              missing_urls.add?(file[:url])
            elsif queued.add?(file[:url])
              queue << file[:url]
            end
          end
        
          #Save to file
        when :file
          files[result[:url]] ||= result
          notify_update(:file, result)
        when :missing
          missing << result
          missing_urls.add?(result[:url])
        end
      end

      #Sort and Storing block
      {
        domains: @domains,
        pages: pages,
        files: files.values,
        missing: missing,
        captchas: captchas,
        errors: errors,
        visited: visited.to_a,
        stopped_for_captcha: !captchas.empty?,
        stopped_by_user: stop_requested?,
        truncated: false
      }
    end

    private

    def stop_requested?
      @stop_mutex.synchronize { @stop_requested }
    end

    def notify_update(type, item)
      @on_update&.call(type, item)
    end

    def record_crawl_error(errors, failed_urls, url, error)
      failed_urls.add(url)
      errors << { url: url, error: "#{error.class}: #{error.message}".encode(Encoding::UTF_8, invalid: :replace, undef: :replace) }
    end

    def extract_and_enqueue_links(page, queue, queued)
      links = @processor.process(page[:body], page[:url])
      links.each do |link|
        next unless link[:kind] == :page

        queue << link[:url] if queued.add?(link[:url])
      end
      links
    end

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
