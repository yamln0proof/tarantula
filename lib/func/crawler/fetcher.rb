#Copyright (c) 2026 Nabil Ahmed

#Libraries
require 'net/http'
require 'uri'

module Tarantula
    module Func
        module Crawler
            class Fetcher
                def self.fetch(url)
                    uri = URI.parse(url)
                    response = Net::HTTP.get_response(uri)
                    response['User-Agent'] = 'Tarantula'
                    response_to=response.body if response.is_a?(Net::HTTPSuccess)
                rescue StandardError => e
                    puts "Error occurred while fetching the URL: #{e.message}"
                    nil
                end
            end
        end
                