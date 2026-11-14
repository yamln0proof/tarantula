#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true

require "net/http"
require "openssl"
require "set"
require "timeout"
require "uri"
require_relative "domain_scope"
require_relative "../../config/settings"

module Tarantula
  class Fetcher
    HTML_EXTENSIONS = %w[.htm .html .xhtml].freeze
    MAX_HTML_BYTES = 50 * 1024 * 1024
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    MAX_REDIRECTS = 5

    #Initialization 
    def initialize(domains:, max_html_bytes: MAX_HTML_BYTES, open_timeout: OPEN_TIMEOUT,
                   read_timeout: READ_TIMEOUT, max_redirects: MAX_REDIRECTS,
                   requests_per_minute: 0, custom_header: "", stop_requested: -> { false })
      @domains = domains.map { |domain| normalize_domain(domain) }.to_set.freeze
      raise ArgumentError, "Provide at least one domain" if @domains.empty?

      @max_html_bytes = Integer(max_html_bytes)
      raise ArgumentError, "max_html_bytes must be positive" unless @max_html_bytes.positive?
      @open_timeout = Integer(open_timeout)
      @read_timeout = Integer(read_timeout)
      @max_redirects = Integer(max_redirects)
      @requests_per_minute = Integer(requests_per_minute)
      @custom_header = Tarantula::Config::Settings.normalize_custom_header(custom_header)
      raise ArgumentError, "timeouts must be positive" unless @open_timeout.positive? && @read_timeout.positive?
      raise ArgumentError, "max_redirects cannot be negative" if @max_redirects.negative?
      raise ArgumentError, "requests_per_minute cannot be negative" if @requests_per_minute.negative?
      raise ArgumentError, "stop_requested must respond to call" unless stop_requested.respond_to?(:call)

      @request_interval = @requests_per_minute.zero? ? nil : 60.0 / @requests_per_minute
      @request_rate_mutex = Mutex.new
      @next_request_at = nil
      @stop_requested_check = stop_requested
    end

    #Main fetching mechanism
    def fetch(url)
      uri = parse_url(url)
      redirects = 0

      loop do
        validate_target!(uri)
        response = request(uri)
        return { url: uri.to_s, kind: :stopped } unless response

        status = response.fetch(:status)

        if [301, 302, 303, 307, 308].include?(status)
          location = response[:location]
          raise IOError, "Redirect response has no Location header: #{uri}" unless location
          raise IOError, "Too many redirects while fetching #{url}" if redirects >= @max_redirects

          uri = resolve_redirect(uri, location)
          redirects += 1
          next
        end

        return { url: uri.to_s, kind: :missing, status: status } if [404, 410].include?(status)
        raise IOError, "HTTP #{status} while fetching #{uri}" unless status.between?(200, 299)

        return classify_response(uri, response)
      end
    rescue SocketError, Timeout::Error, SystemCallError, Net::HTTPError, OpenSSL::SSL::SSLError => error
      raise IOError, "Unable to fetch #{url}: #{error.message}"
    end

    private


    #Request method
    def request(uri)
      return unless wait_for_request_slot

      response_data = {}
      http = Net::HTTP.new(uri.host, uri.port, nil)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http.start do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "Tarantula/0.1"
        if !@custom_header.empty?
          name, value = @custom_header.split(":", 2)
          request[name] = value.strip
        end
        http.request(request) do |response|
          response_data[:status] = response.code.to_i
          response_data[:location] = response["location"]
          response_data[:content_type] = response["content-type"].to_s
          next unless response_data[:status].between?(200, 299)

          response_data[:body] = +"".b
          response_data[:size] = 0
          response.read_body do |chunk|
            response_data[:size] += chunk.bytesize
            remaining = @max_html_bytes + 1 - response_data[:body].bytesize
            response_data[:body] << chunk.byteslice(0, remaining) if remaining.positive?
          end
        end
      end
      response_data
    end

    def wait_for_request_slot
      return false if @stop_requested_check.call
      return true unless @request_interval

      @request_rate_mutex.synchronize do
        while @next_request_at
          remaining = @next_request_at - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break unless remaining.positive?

          return false if @stop_requested_check.call

          sleep([remaining, 0.1].min)
        end
        return false if @stop_requested_check.call

        @next_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @request_interval
      end
      true
    end

    def classify_response(uri, response)
      body = response.fetch(:body)
      content_type = response.fetch(:content_type)
      size = response.fetch(:size)
      html = content_type.match?(%r{\Atext/html\b}i) ||
             content_type.match?(%r{\Aapplication/xhtml\+xml\b}i) ||
             HTML_EXTENSIONS.include?(File.extname(uri.path).downcase) ||
             body.byteslice(0, 512).to_s.force_encoding(Encoding::UTF_8).scrub
                 .match?(/<\s*(?:!doctype\s+html|html|head|body)\b/i)

      return { url: uri.to_s, kind: :file, size: size, content_type: content_type } unless html
      raise IOError, "HTML response exceeds #{@max_html_bytes} bytes: #{uri}" if size > @max_html_bytes

      {
        url: uri.to_s,
        kind: :page,
        size: size,
        content_type: content_type,
        body: body
      }
    end

    #Get correct user input
    def validate_target!(uri)
      unless uri.is_a?(URI::HTTP) && uri.host && uri.userinfo.nil?
        raise ArgumentError, "Only HTTP(S) URLs without credentials are supported"
      end
      unless DomainScope.includes?(@domains, uri.host)
        raise ArgumentError, "URL host is not in the supplied domain list: #{uri.host}"
      end
      return if uri.port == (uri.scheme == "https" ? 443 : 80)

      raise ArgumentError, "Non-standard ports are not allowed: #{uri}"
    end

    def parse_url(url)
      uri = URI.parse(url)
      uri
    rescue URI::InvalidURIError => e
      raise ArgumentError, "Invalid URL: #{e.message}"
    end

    def resolve_redirect(uri, location)
      parse_url(URI.join(uri.to_s, location).to_s)
    rescue URI::InvalidURIError => e
      raise IOError, "Invalid redirect URL from #{uri}: #{e.message}"
    end

    def normalize_domain(domain)
      normalized = domain.to_s.strip.downcase
      unless normalized.match?(/\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/) && !normalized.include?("..")
        raise ArgumentError, "Invalid domain name: #{domain}"
      end

      normalized
    end
  end
end
