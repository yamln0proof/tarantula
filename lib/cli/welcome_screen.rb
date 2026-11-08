#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true

require "curses"

module Tarantula
  module CLI
    class WelcomeScreen
      OPTIONS = [
        ["Crawl", :start],
        ["Configure Settings", :settings],
        ["View Saved Logs", :logs],
        ["Exit", :exit]
      ].freeze
      SPIDER_LOGO = [
        "       |",
        "       |",
        "      /|\\",
        "   __/ | \\__",
        "   \\  (@)  /",
        "    \\ /|\\ /",
        "     / | \\",
        "    /  |  \\"
      ].freeze

      def self.run
        new.run
      end

      def run
        Curses.init_screen
        @screen_open = true
        @window = Curses.stdscr

        setup_terminal
        welcome_screen
      ensure
        Curses.close_screen if @screen_open
      end

      private

      def setup_terminal
        Curses.noecho
        Curses.cbreak
        Curses.curs_set(0)
        @window.keypad(true)

        return unless Curses.has_colors?

        Curses.start_color
        Curses.init_pair(1, Curses::COLOR_CYAN, Curses::COLOR_BLACK)
        Curses.init_pair(2, Curses::COLOR_GREEN, Curses::COLOR_BLACK)
        Curses.init_pair(3, Curses::COLOR_BLACK, Curses::COLOR_CYAN)
        Curses.init_pair(4, Curses::COLOR_RED, Curses::COLOR_BLACK)
      end

      def welcome_screen
        selection = 0

        loop do
          draw_screen(selection)
          key = @window.getch
          key = key.chr if key.is_a?(Integer) && key <= 127

          case key
          when Curses::KEY_UP, "k", "K"
            selection = (selection - 1) % OPTIONS.length
          when Curses::KEY_DOWN, "j", "J"
            selection = (selection + 1) % OPTIONS.length
          when Curses::KEY_ENTER, "\n", "\r"
            return OPTIONS[selection][1]
          when "q", "Q", "\e"
            return :exit
          end
        end
      end

      def draw_screen(selection)
        @window.clear

        SPIDER_LOGO.each_with_index do |line, index|
          write_centered(index, line, color(4))
        end
        write_centered(9, "Tarantula: Web Crawler", color(1))
        write_centered(10, "Crawl Your need.", color(2))
        write_centered(12, "-" * [Curses.cols - 8, 0].max, Curses::A_NORMAL)

        menu_top = [Curses.lines / 2 - OPTIONS.length / 2, 14].max
        OPTIONS.each_with_index do |(label, _action), index|
          if index == selection
            write_centered(menu_top + index, "  > #{label}  ", color(3))
          else
            write_centered(menu_top + index, "    #{label}", Curses::A_NORMAL)
          end
        end

        write_at(Curses.lines - 2, 0, "Up/Down or j/k: move | Enter: select | q: quit", Curses::A_REVERSE)
        @window.refresh
      end

      def write_centered(row, text, attribute)
        return if Curses.cols <= 0

        text = text[0, Curses.cols]
        column = [(Curses.cols - text.length) / 2, 0].max
        write_at(row, column, text, attribute)
      end

      def write_at(row, column, text, attribute)
        return if row.negative? || row >= Curses.lines || column.negative? || column >= Curses.cols

        text = text[0, Curses.cols - column]
        @window.setpos(row, column)
        @window.attrset(attribute)
        @window.addstr(text)
        @window.attrset(Curses::A_NORMAL)
      end

      def color(pair)
        Curses.has_colors? ? Curses.color_pair(pair) : Curses::A_NORMAL
      end
    end
  end
end
