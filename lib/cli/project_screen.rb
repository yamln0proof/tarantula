#Copyright (c) 2026 Nabil Ahmed
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
        @output.puts "Live HTTP(S) crawl restricted to supplied domains"
        @output.print "Domains (comma-separated or @domain-file): "
        domain_input = @input.gets&.strip
        return if domain_input.nil? || domain_input.empty?

        result = if domain_input.start_with?("@")
                   domains_file = domain_input.delete_prefix("@").strip
                   raise ArgumentError, "Enter a domain file path after @." if domains_file.empty?

                   Worker::Crawler.new(domains_file: domains_file).run
                 else
                   Worker::Crawler.new(domain_input.split(",")).run
                 end
        crawl = @database.store_crawl(domains: result.fetch(:domains), result: result)
        print_summary(result)
        @output.puts "Saved crawl: #{crawl[:id]}"
        result
      end

      private

      def print_summary(result)
        @output.puts "HTML pages: #{result[:pages].length}"
        @output.puts "Files: #{result[:files].length}"
        @output.puts "Missing links: #{result[:missing].length}"
        @output.puts "CAPTCHA detected; crawl stopped." if result[:stopped_for_captcha]
        @output.puts "Stopped at the page limit." if result[:truncated]
      end
    end
  end
end
