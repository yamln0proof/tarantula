# Copyright (c) 2026 Nabil Ahmed

require 'mongo'

module Tarantula
  module Config
    class Mongo
      def self.client
        @client ||= ::Mongo::Client.new(
          ENV.fetch('MONGODB_URI', 'mongodb://127.0.0.1:27017/tarantula_development')
        )
      end
    end
  end
end
