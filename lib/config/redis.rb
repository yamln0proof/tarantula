#Copyright (c) 2026 Nabil Ahmed

require 'redis'

#Redis configuration for Tarantula.
module Tarantula
  module Config
    class Redis
      def self.client
        @client ||= ::Redis.new(
          host: ENV.fetch('REDIS_HOST', 'localhost'),
          port: ENV.fetch('REDIS_PORT', 6379),
          db: ENV.fetch('REDIS_DB', 0)
        )
      end
    end
  end
end

