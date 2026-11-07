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

        def self.store_request(url, header, request_body)
            requests_collection = ENV.fetch('REQUESTS_COLLECTION', 'requests')
            client[requests_collection].insert_one(
            url: url,
            request: request_body
            requested_at: Time.now.utc
            )
        end

        def self.store_page(url, status, header, response_body)
            pages_collection = ENV.fetch('PAGES_COLLECTION', 'pages')
            client[pages_collection].insert_one(
                url: url,
                status: status
                header: header
                request: response_body
                requested_at: Time.now.utc

            )
        end
    end
end
