# frozen_string_literal: true

require "uri"

module Tarantula
  class Fetcher
    HTML_EXTENSIONS = %w[.htm .html .xhtml].freeze
    MAX_HTML_BYTES = 5 * 1024 * 1024

    def initialize(fixture_root:, domains:, max_html_bytes: MAX_HTML_BYTES)
      @fixture_root = File.realpath(fixture_root)
      @domains = domains.to_h do |domain|
        normalized_domain = domain.downcase
        domain_path = File.realpath(File.join(@fixture_root, normalized_domain))
        unless contained_by?(@fixture_root, domain_path)
          raise ArgumentError, "Fixture directory must be inside the fixture root"
        end

        [normalized_domain, domain_path]
      end.freeze
      @max_html_bytes = Integer(max_html_bytes)
      raise ArgumentError, "max_html_bytes must be positive" unless @max_html_bytes.positive?
    end

    def fetch(url)
      uri = parse_url(url)
      domain_root = @domains[uri.host.downcase]
      raise ArgumentError, "URL host is not in the supplied domain list" unless domain_root

      file_path = resolve_file_path(uri, domain_root)
      return { url: uri.to_s, kind: :missing, path: file_path } unless file_path

      size = File.size(file_path)
      if html_file?(file_path)
        body = File.binread(file_path, @max_html_bytes + 1)
        if size > @max_html_bytes || body.bytesize > @max_html_bytes
          raise ArgumentError, "HTML fixture exceeds #{@max_html_bytes} bytes: #{file_path}"
        end

        {
          url: uri.to_s,
          kind: :page,
          path: file_path,
          size: size,
          body: body
        }
      else
        { url: uri.to_s, kind: :file, path: file_path, size: size }
      end
    end

    private

    def parse_url(url)
      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTP) && uri.host && uri.userinfo.nil?
        raise ArgumentError, "Only HTTP(S) fixture URLs are supported"
      end

      uri
    rescue URI::InvalidURIError => e
      raise ArgumentError, "Invalid fixture URL: #{e.message}"
    end

    def resolve_file_path(uri, domain_root)
      relative_path = URI::DEFAULT_PARSER.unescape(uri.path)
      raise ArgumentError, "Invalid path in fixture URL" if relative_path.include?("\0")

      candidate = File.join(domain_root, relative_path.delete_prefix("/"))
      if File.directory?(candidate)
        candidate = File.join(candidate, "index.html")
        candidate = File.join(File.dirname(candidate), "index.htm") unless File.file?(candidate)
      end
      return unless File.file?(candidate)

      resolved_path = File.realpath(candidate)
      return unless contained_by?(domain_root, resolved_path)

      resolved_path
    end

    def html_file?(path)
      return true if HTML_EXTENSIONS.include?(File.extname(path).downcase)

      prefix = File.open(path, "rb") { |file| file.read(512) }.to_s
      prefix.force_encoding(Encoding::UTF_8).scrub.match?(/<\s*(?:!doctype\s+html|html|head|body)\b/i)
    end

    def contained_by?(root, path)
      path == root || path.start_with?("#{root}#{File::SEPARATOR}")
    end
  end
end
