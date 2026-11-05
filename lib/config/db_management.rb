#Copyright (c) 2026 Nabil Ahmed

#Libraries
require 'mongo'

module Tarantula
    module Config
        class Mongo
        def self.client
            @client ||= ::Mongo::Client.new(
            ENV.fetch('MONGODB_URI', 'mongodb://localhost:27017/tarantula')
            )
        end

        def self.database
            @database ||= client.database
        end

        def self.store_request(url, request_body, error_message = nil)
            requests_collection = ENV.fetch('REQUESTS_COLLECTION', 'requests')
            client[requests_collection].insert_one(
            url: url,
            request: request_body,
            error_message: error_message,
            requested_at: Time.now.utc
            )
        end

        def self.store_page(url, response_body)
            pages_collection = ENV.fetch('PAGES_COLLECTION', 'pages')
            client[pages_collection].insert_one(
            url: url,
            response: response_body,
            crawled_at: Time.now.utc
            )
        end
    end
end
