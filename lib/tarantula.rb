#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true

require_relative "tarantula/version"
require_relative "config/mongo"
require_relative "config/redis"
require_relative 'cli/main_screen'
require_relative 'cli/welcome_screen'
require_relative 'cli/project_screen'
require_relative 'cli/transaction_screen'


module Tarantula
  class Error < StandardError; end
  # Your code goes here...

  class Main
    def initialization
      welcome = Tarantula::CLI::WelcomeScreen.run()
      #DB, Screens, Models, Project initialization.
  
end
