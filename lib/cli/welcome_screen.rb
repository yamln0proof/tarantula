#Libraries
require 'curses'

module Tarantula
    module CLI
        class WelcomeScreen
            include Curses
            def initialize

                #Setup standared curses parameters
                init_screen
                start_color
                curs_set(1)
                noecho
                cbreak
                stdscr.keypad(true)

                #Initialize color pairs
                init_pair(1, COLOR_CYAN, COLOR_BLACK)
                init_pair(2, COLOR_GREEN, COLOR_BLACK)
                init_pair(3, COLOR_BLACK, COLOR_CYAN)
                init_pair(4, COLOR_RED, COLOR_BLACK)
            end

            def run
                begin
                    welcome_screen
                ensure
                    close_screen
                end
            end
            private


            def welcome_screen
                options = ["Start Tarantula", "Configure Settings", "View Saved Logs", "Exit"]
                current_selection = 0

                loop do
                    clear

                    max_y = lines
                    max_x = cols

                    #Top Title Baner
                    attron(colo)


