#Copyright (c) 2026 Nabil Ahmed

#Libraries
require 'net/http'
require 'uri'
require_relative '../../config/db_management'

module Tarantula
    class Fetcher
        #Initialization
        def initialize(user_agent, open_timeout, read_timeout, max_redirects)
            @user_agent = 'Tarantula-Bot/1.0'
            @open_timeout = 5
            @read_timeout = 10
            @max_redirects = 5
        end

        #Fetching Logic
        def fetch(uri_string, limit = @max_redirects)
            raise ArgumentError, 'Too many HTTP redirects' if limit <= 0

            uri = URI.parse(uri_string)
            http = build_http_client(uri)

            request = Net::HTTP::Get.new(uri)
            request['User-Agent'] = @user_agent
            request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'

            response = http.request(request)

            #Response Management
            case response
            when Net::HTTPSuccess
                {
                    final_uri: uri.to_s 
                    status: response.code.to_i,
                    headers: response.to_hash
                    body: response.body
                    request: request.body

                    #Store in DB
                    Tarantula::Config::Mongo.store_page(final_uri, status, headers, response)

                    Tarantula::Config::Mongo.store_request(final_uri, request)
                }
            when Net::HttpReditaction
                {
                    location = response['location']
                    raise "Rediract missing location header" unless location

                    #Handle relative redirect urls
                    next_uri = URI.join(uri, location).to_s
                    fetch(next_uri, limit -1)
                }
            else
                {
                    status: response.code.to_i,
                    message: response.message,
                    body: response.body,
                    final_uri: uri.to_s 
                }
            end
        #Error Handler    
        rescue StandaredError => e
            {
                error: e.message,
                final_uri: uri_string
            }
        end
        private

        def build_http_client(uri)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == 'https')
            http.open_timeout = @open_timeout
            http.read_timeout = @read_timeout
            http
        end
            