#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true

require_relative "tarantula/version"
require_relative "cli/welcome_screen"
require_relative "cli/main_screen"
require_relative "cli/transaction_screen"

module Tarantula
  class Error < StandardError; end

  class Main
    def self.run
      new.run
    end

    def run
      loop do
        case CLI::WelcomeScreen.run
        when :start
          CLI::MainScreen.run
        when :logs
          CLI::TransactionScreen.run
        when :settings
          $stdout.puts "Settings screen is not available yet."
        when :exit, nil
          return :exit
        else
          raise Error, "Welcome screen returned an unknown action"
        end
      end
    end
  end

  def self.run
    Main.run
  end
end
