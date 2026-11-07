#Copyright (c) 2026 Nabil Ahmed

#Libraries
require 'net/http'
require 'uri'
require 'set'
require 'mongo'


module Tarantula
    class Processor
        #Initialization
        def initialize(links)
            @@links = []

        end

        #Processing Logic
        def process(html, url)
            begin
                html.scan(/<a\s+(?:[^>]*?\s+)?href=(["'])(.*?)\1/) do |match|
                    link = match[1]
                    link = URI.join(url, link).to_s rescue next
                    links << link
                end
                return links.uniq
            rescue StandardError => e
                puts "Error occurred while processing the HTML: #{e.message}"
                []
            end
        end
    end
end


