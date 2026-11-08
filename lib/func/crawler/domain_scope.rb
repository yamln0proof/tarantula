#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true


module Tarantula
  module DomainScope
    def self.includes?(domains, host)
      host = host.to_s.downcase
      domains.any? do |domain|
        scope = domain.sub(/\Awww\./, "")
        host == scope || host.end_with?(".#{scope}")
      end
    end
  end
end
