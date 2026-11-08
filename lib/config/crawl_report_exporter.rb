# frozen_string_literal: true

require "fileutils"
require "json"

module Tarantula
  module Config
    class CrawlReportExporter
      def initialize(directory: Dir.pwd)
        @report_directory = File.join(File.expand_path(directory), "reports")
      end

      def export(crawl)
        crawl_id = crawl.fetch(:id)
        FileUtils.mkdir_p(@report_directory)
        base_path = File.join(@report_directory, "crawl-#{crawl_id}")
        json_path = "#{base_path}.json"
        text_path = "#{base_path}.txt"

        File.write(json_path, "#{JSON.pretty_generate(crawl)}\n")
        File.write(text_path, text_report(crawl))

        { json: json_path, text: text_path }
      rescue JSON::GeneratorError => error
        raise IOError, "Unable to generate crawl report: #{error.message}"
      end

      private

      def text_report(crawl)
        pages = Array(crawl[:pages])
        files = Array(crawl[:files])
        missing = Array(crawl[:missing])
        captchas = Array(crawl[:captchas])
        errors = Array(crawl[:errors])
        lines = [
          "Tarantula Crawl Report",
          "Crawl ID: #{crawl[:id]}",
          "Created at: #{crawl[:created_at]}",
          "Domains: #{Array(crawl[:domains]).join(', ')}",
          "",
          "Summary",
          "Pages: #{pages.length}",
          "Files: #{files.length}",
          "Missing links: #{missing.length}",
          "CAPTCHAs: #{captchas.length}",
          "Crawl errors: #{errors.length}",
          "Stopped for CAPTCHA: #{crawl[:stopped_for_captcha] ? 'yes' : 'no'}",
          "Stopped by user: #{crawl[:stopped_by_user] ? 'yes' : 'no'}",
          "Truncated: #{crawl[:truncated] ? 'yes' : 'no'}",
          "",
          "Pages"
        ]
        lines.concat(pages.map { |page| "  #{page[:url]}" })
        lines.concat(["", "Files"])
        lines.concat(files.map { |file| "  #{file[:url]} (#{file[:size]} bytes)" })
        lines.concat(["", "Missing links"])
        lines.concat(missing.map { |item| "  #{item[:url]}" })
        lines.concat(["", "CAPTCHAs"])
        lines.concat(captchas.map do |captcha|
          "  #{captcha[:url]} (confidence: #{captcha[:confidence]}; signals: #{Array(captcha[:signals]).join(', ')})"
        end)
        lines.concat(["", "Crawl errors"])
        lines.concat(errors.map { |error| "  #{error[:url]}: #{error[:error]}" })
        lines.concat(["", "Visited URLs"])
        lines.concat(Array(crawl[:visited]).map { |url| "  #{url}" })
        lines.join("\n") + "\n"
      end
    end
  end
end
