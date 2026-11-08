#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true

require "nokogiri"
require "set"
require "uri"

module Tarantula
  class Processor
    FILE_EXTENSIONS = %w[
      .7z .avi .css .csv .doc .docx .eot .gif .gz .ico .jpeg .jpg .js .json
      .mp3 .mp4 .pdf .png .ppt .pptx .rar .svg .tar .tgz .ttf .txt .wav
      .webm .webp .woff .woff2 .xls .xlsx .xml .zip
    ].to_set.freeze

    RESOURCE_SELECTORS = [
      ["a[href], area[href], link[href]", "href", :page_or_file],
      ["iframe[src]", "src", :page_or_file],
      ["img[src], script[src], source[src], video[src], audio[src], track[src], embed[src]", "src", :file],
      ["video[poster]", "poster", :file],
      ["object[data]", "data", :file]
    ].freeze

    #Initialization
    def initialize(domains:)
      @domains = Array(domains).flat_map do |domain|
        domain.to_s.split(/[,\s]+/)
      end.map(&:strip).reject(&:empty?).map(&:downcase).to_set.freeze
    end

    #Main processing mechanism
    def process(html, page_url)
      document = Nokogiri::HTML(html)
      links = {}

      RESOURCE_SELECTORS.each do |selector, attribute, default_kind|
        document.css(selector).each do |element|
          url = normalize_url(page_url, element[attribute])
          next unless url

          kind = default_kind == :file || file_url?(url) ? :file : :page
          links[url] ||= { url: url, kind: kind }
        end
      end

      links.values
    end

    private

    #Normalization
    def normalize_url(page_url, reference)
      return if reference.nil? || reference.strip.empty?

      url = URI.join(page_url, reference.strip)
      return unless url.is_a?(URI::HTTP) && @domains.include?(url.host&.downcase)
      return unless url.userinfo.nil?
      return unless url.port == (url.scheme == "https" ? 443 : 80)

      url.fragment = nil
      url.query = nil
      url.to_s
    rescue URI::InvalidURIError
      nil
    end

    def file_url?(url)
      FILE_EXTENSIONS.include?(File.extname(URI(url).path).downcase)
    end
  end
end
