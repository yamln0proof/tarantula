# frozen_string_literal: true

require_relative "../func/crawler/worker"
require_relative "../config/crawl_database"

module Tarantula
  module CLI
    class ProjectScreen
      def self.run(input: $stdin, output: $stdout, database: nil)
        new(input: input, output: output, database: database).run
      end

      def initialize(input:, output:, database: nil)
        @input = input
        @output = output
        @database = database || Tarantula::Config::CrawlDatabase.new
      end

      def run
        @output.puts "Local HTML fixture crawl (no network requests)"
        @output.print "Fixture root directory: "
        fixture_root = @input.gets&.strip
        return if fixture_root.nil? || fixture_root.empty?

        @output.print "Domains (comma-separated; each must have a matching subdirectory): "
        domains = @input.gets.to_s.split(",").map(&:strip).reject(&:empty?)
        raise ArgumentError, "Provide at least one domain" if domains.empty?

        result = Worker::Crawler.new(domains, fixture_root: fixture_root).run
        crawl = @database.store_crawl(domains: domains, result: result)
        print_summary(result)
        @output.puts "Saved crawl: #{crawl[:id]}"
        result
      end

      private

      def print_summary(result)
        @output.puts "HTML pages: #{result[:pages].length}"
        @output.puts "Files: #{result[:files].length}"
        @output.puts "Missing links: #{result[:missing].length}"
        @output.puts "Stopped at the page limit." if result[:truncated]
      end
    end
  end
end
