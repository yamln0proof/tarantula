# frozen_string_literal: true

module Tarantula
  module Config
    class Settings
      HTTP_HEADER_NAME = /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/
      DEFAULTS = {
        open_timeout: 5,
        read_timeout: 10,
        max_redirects: 5,
        max_html_bytes: 50 * 1024 * 1024,
        requests_per_minute: 0,
        custom_header: "",
        database_path: ENV.fetch(
          "TARANTULA_DATABASE_PATH",
          File.expand_path("../../data/tarantula-crawls.json", __dir__)
        ),
        captcha_threshold: 0.75
      }.freeze

      def initialize
        @values = DEFAULTS.dup
      end

      def [](name)
        @values.fetch(name)
      end

      def update(name, value)
        @values[name] = normalize(name, value)
      end

      def self.normalize_custom_header(value)
        header = value.to_s
        if header.match?(/[\r\n\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/)
          raise ArgumentError, "custom_header must be a valid 'Name: Value' header"
        end

        header = header.strip
        return "" if header.empty?

        name, header_value = header.split(":", 2)
        name = name&.strip
        unless header_value && HTTP_HEADER_NAME.match?(name.to_s)
          raise ArgumentError, "custom_header must be a valid 'Name: Value' header"
        end

        "#{name}: #{header_value.strip}"
      end

      private

      def normalize(name, value)
        case name
        when :open_timeout, :read_timeout, :max_html_bytes
          integer = Integer(value)
          raise ArgumentError, "#{name} must be positive" unless integer.positive?

          integer
        when :max_redirects
          integer = Integer(value)
          raise ArgumentError, "max_redirects cannot be negative" if integer.negative?

          integer
        when :requests_per_minute
          integer = Integer(value)
          raise ArgumentError, "requests_per_minute cannot be negative" if integer.negative?

          integer
        when :custom_header
          self.class.normalize_custom_header(value)
        when :database_path
          path = value.to_s.strip
          raise ArgumentError, "database_path cannot be empty" if path.empty?

          File.expand_path(path)
        when :captcha_threshold
          threshold = Float(value)
          raise ArgumentError, "captcha_threshold must be between 0 and 1" unless threshold.between?(0.0, 1.0)

          threshold
        else
          raise ArgumentError, "Unknown setting: #{name}"
        end
      rescue ArgumentError, TypeError
        raise ArgumentError, "Invalid value for #{name}: #{value.inspect}"
      end
    end
  end
end
