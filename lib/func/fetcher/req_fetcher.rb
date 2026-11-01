#Copyright (c) 2026 Nabil Ahmed

require 'net/http'
require 'uri'

module Tarantula
    module Fetcher
        class ReqFetcher
            MAX_RETRIES = 3
            MAX_REDIRECTS = 5

            def self.fetch(url, user_agent: 'TarantulaBot', delay, limitRetries=MAX_RETRIES, limitRedirects=MAX_REDIRECTS)
                # TODO: Implement politeness check here using Tarantula::Politeness
                
            end

        end
    end