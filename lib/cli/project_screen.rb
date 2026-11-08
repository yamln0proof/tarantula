#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true

require_relative "../func/crawler/worker"
require_relative "../config/crawl_database"
require_relative "../config/crawl_report_exporter"
require_relative "../config/settings"

module Tarantula
  module CLI
    class ProjectScreen
      def self.run(input: $stdin, output: $stdout, database: nil, settings: Tarantula::Config::Settings.new)
        new(input: input, output: output, database: database, settings: settings).run
      end

      def initialize(input:, output:, database: nil, settings: Tarantula::Config::Settings.new)
        @input = input
        @output = output
        @database = database || Tarantula::Config::CrawlDatabase.new(path: settings[:database_path])
        @settings = settings
      end

      
      def run
        @output.puts "Live HTTP(S) crawl"
        @output.print "Domains (comma-separated or @domain-file): "
        domain_input = @input.gets&.strip
        return if domain_input.nil? || domain_input.empty?

        result = if domain_input.start_with?("@")
                   domains_file = domain_input.delete_prefix("@").strip
                   raise ArgumentError, "Enter a domain file path after @." if domains_file.empty?

                   Worker::Crawler.new(domains_file: domains_file, settings: @settings).run
                 else
                   Worker::Crawler.new(domain_input.split(","), settings: @settings).run
                 end
        crawl = @database.store_crawl(domains: result.fetch(:domains), result: result)
        report_paths = Tarantula::Config::CrawlReportExporter.new.export(crawl)
        print_summary(result)
        @output.puts "Saved crawl: #{crawl[:id]}"
        @output.puts "JSON report: #{report_paths[:json]}"
        @output.puts "Text export: #{report_paths[:text]}"
        result
      end

      private

      #Result box
      def print_summary(result)
        @output.puts "HTML pages: #{result[:pages].length}"
        @output.puts "Files: #{result[:files].length}"
        @output.puts "Missing links: #{result[:missing].length}"
        Array(result[:errors]).each do |error|
          @output.puts "Crawl error for #{error[:url]}: #{error[:error]}"
        end
        @output.puts "CAPTCHA detected; crawl stopped." if result[:stopped_for_captcha]
        @output.puts "Crawl stopped by user." if result[:stopped_by_user]
        @output.puts "Stopped at the page limit." if result[:truncated]
      end
    end
  end
end
