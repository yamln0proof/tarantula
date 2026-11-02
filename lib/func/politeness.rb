#Copyright (c) 2026 Nabil Ahmed

require 'uri'
require 'robotex'
require_relative 'tarantula/version'

module Tarantula
    module Politeness

        #robots.txt file check.
        class PolitenessCheck
            def initialize(url)
                @url = url
                @robotex = Robotex.new(robot_name: @@robot)

            end

            # #Robots.txt check.
            # def robots_check
            #     begin
            #         uri = URI.parse(@url)
            #         if @robotex.allowed?(@url)
            #             return true
            #         else
            #             return false
            #         end
            #     rescue URI::InvalidURIError => e
            #         return false
            #     end
            # end
        end 
        
        #Rate limit check.
        class Throttle
            def initialize(rate_limit)
                @rate_limit = rate_limit
                @last_request_time = Time.now
            end

            def throttle_request
                time_since_last_request = Time.now - @last_request_time
                if time_since_last_request < @rate_limit
                    sleep(@rate_limit - time_since_last_request)
                end
                @last_request_time = Time.now
            end
        end

        #Usage : throttle = Throttle.new(1); throttle.throttle_request


        
        
    end
end
