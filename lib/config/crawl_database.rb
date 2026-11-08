# frozen_string_literal: true

require "fileutils"
require "json"
require "securerandom"
require "tempfile"
require "time"

module Tarantula
  module Config
    class CrawlDatabase
      SCHEMA_VERSION = 1
      DEFAULT_PATH = File.expand_path("../../data/tarantula-crawls.json", __dir__)

      attr_reader :path

      def initialize(path: ENV.fetch("TARANTULA_DATABASE_PATH", DEFAULT_PATH))
        @path = File.expand_path(path)
        create_database
      end

      def create_database
        FileUtils.mkdir_p(File.dirname(path))
        with_lock(File::LOCK_EX) do
          write_state(empty_state) unless File.exist?(path)
        end
        path
      end

      def store_crawl(domains:, result:)
        crawl = {
          id: SecureRandom.uuid,
          created_at: Time.now.utc.iso8601,
          domains: domains,
          pages: result.fetch(:pages),
          files: result.fetch(:files),
          missing: result.fetch(:missing),
          captchas: result.fetch(:captchas, []),
          errors: result.fetch(:errors, []),
          visited: result.fetch(:visited),
          stopped_for_captcha: result.fetch(:stopped_for_captcha, false),
          truncated: result.fetch(:truncated)
        }

        with_lock(File::LOCK_EX) do
          state = read_state
          state.fetch(:crawls) << crawl
          write_state(state)
        end

        crawl
      end

      def recent_crawls(limit: 100)
        limit = Integer(limit)
        raise ArgumentError, "limit must be positive" unless limit.positive?

        with_lock(File::LOCK_SH) do
          read_state.fetch(:crawls).last(limit).reverse
        end
      end

      def find_crawl(id)
        with_lock(File::LOCK_SH) do
          read_state.fetch(:crawls).find { |crawl| crawl[:id] == id }
        end
      end

      private

      def lock_path
        "#{path}.lock"
      end

      def with_lock(mode)
        File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
          lock.flock(mode)
          yield
        ensure
          lock.flock(File::LOCK_UN)
        end
      end

      def empty_state
        { schema_version: SCHEMA_VERSION, crawls: [] }
      end

      def read_state
        state = JSON.parse(File.read(path), symbolize_names: true)
        unless state[:schema_version] == SCHEMA_VERSION && state[:crawls].is_a?(Array)
          raise IOError, "Unsupported or invalid crawl database schema: #{path}"
        end

        state
      rescue JSON::ParserError => e
        raise IOError, "Unable to read crawl database #{path}: #{e.message}"
      end

      def write_state(state)
        Tempfile.create([".#{File.basename(path)}.", ".tmp"], File.dirname(path)) do |file|
          file.write(JSON.generate(state))
          file.flush
          file.fsync
          File.rename(file.path, path)
        end
      end
    end
  end
end
