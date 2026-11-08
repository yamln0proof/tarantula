# frozen_string_literal: true
#Copyright (c) 2026 Nabil Ahmed

require "nokogiri"

module Tarantula
  class CaptchaDetector
    THRESHOLD = 0.75

    SIGNAL_WEIGHTS = {
      provider_markup: 0.98,
      response_field: 0.99,
      challenge_text: 0.88,
      captcha_title: 0.82,
      captcha_text: 0.60
    }.freeze

    PROVIDER_PATTERN = /(?:recaptcha|hcaptcha|cf-turnstile|challenges\.cloudflare\.com)/i
    RESPONSE_FIELD_PATTERN = /\A(?:g-recaptcha-response|h-captcha-response|cf-turnstile-response)\z/i
    CHALLENGE_TEXT_PATTERN = /
      \b(?:verify\s+(?:that\s+)?you(?:'re|\s+are)\s+human|
      prove\s+(?:that\s+)?you(?:'re|\s+are)\s+human|
      are\s+you\s+(?:a\s+)?robot|
      automated\s+requests|
      complete\s+(?:the\s+)?captcha|
      captcha\s+verification|
      security\s+check)\b
    /ix

    def initialize(threshold: THRESHOLD)
      @threshold = Float(threshold)
      raise ArgumentError, "threshold must be between 0 and 1" unless @threshold.between?(0.0, 1.0)
    end

    def detect(html)
      document = Nokogiri::HTML(html.to_s)
      title = document.at_css("title")&.text.to_s
      visible_text = document.xpath(
        "//body//text()[not(ancestor::script or ancestor::style or ancestor::noscript)]"
      ).map(&:text).join(" ")
      signals = []

      attribute_values = document.css("[src], [class], [id], [name], [data-sitekey], [aria-label]")
                               .flat_map { |element| element.attribute_nodes.map(&:value) }
      signals << :provider_markup if PROVIDER_PATTERN.match?(attribute_values.join(" "))
      signals << :response_field if document.css("input[name], textarea[name]").any? do |field|
        RESPONSE_FIELD_PATTERN.match?(field["name"].to_s)
      end
      signals << :challenge_text if CHALLENGE_TEXT_PATTERN.match?("#{title} #{visible_text}")
      signals << :captcha_title if /\bcaptcha\b/i.match?(title)
      signals << :captcha_text if /\bcaptcha\b/i.match?(visible_text)

      confidence = 1.0 - signals.reduce(1.0) do |remaining, signal|
        remaining * (1.0 - SIGNAL_WEIGHTS.fetch(signal))
      end

      {
        detected: confidence >= @threshold,
        confidence: confidence.round(3),
        signals: signals.map(&:to_s)
      }
    end
  end
end
