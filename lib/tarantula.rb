#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true

require_relative "tarantula/version"
require_relative "config/settings"
require_relative "cli/welcome_screen"
require_relative "cli/main_screen"
require_relative "cli/settings_screen"
require_relative "cli/transaction_screen"
require_relative "config/crawl_database"

module Tarantula
  class Error < StandardError; end

  class Main
    def self.run
      new.run
    end

    def run
      @settings = Config::Settings.new
      loop do
        case CLI::WelcomeScreen.run
        when :start
          CLI::MainScreen.run(settings: @settings)
        when :logs
          CLI::TransactionScreen.run(database_path: @settings[:database_path])
        when :settings
          CLI::SettingsScreen.run(settings: @settings)
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
