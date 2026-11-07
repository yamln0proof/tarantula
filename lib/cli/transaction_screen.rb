# frozen_string_literal: true

require "curses"
require_relative "../config/crawl_database"

module Tarantula
  module CLI
    class TransactionScreen
      def self.run(database: Tarantula::Config::CrawlDatabase.new)
        new(database: database).run
      end

      def initialize(database:)
        @database = database
      end

      def run
        @crawls = @database.recent_crawls
        @selection = 0
        @details = false
        @details_offset = 0

        Curses.init_screen
        @screen_open = true
        @window = Curses.stdscr
        Curses.noecho
        Curses.cbreak
        Curses.curs_set(0)
        @window.keypad(true)

        event_loop
      ensure
        Curses.close_screen if @screen_open
      end

      private

      def event_loop
        loop do
          draw_screen
          key = @window.getch
          key = key.chr if key.is_a?(Integer) && key <= 127

          case key
          when "q", "Q"
            return
          when Curses::KEY_UP, "k", "K"
            move_selection(-1)
          when Curses::KEY_DOWN, "j", "J"
            move_selection(1)
          when Curses::KEY_ENTER, "\n", "\r"
            @details = !@details unless @crawls.empty?
            @details_offset = 0
          when Curses::KEY_LEFT, "\e", "b"
            @details = false
            @details_offset = 0
          end
        end
      end

      def move_selection(amount)
        if @details
          @details_offset = [@details_offset + amount, 0].max
        elsif !@crawls.empty?
          @selection = [[@selection + amount, 0].max, @crawls.length - 1].min
        end
      end

      def draw_screen
        @window.clear
        draw_text(0, "TARANTULA - SAVED CRAWLS", Curses::A_REVERSE)
        draw_text(1, "-" * [Curses.cols - 1, 0].max, Curses::A_NORMAL)

        if @crawls.empty?
          draw_text(3, "No crawls have been saved yet.", Curses::A_NORMAL)
        elsif @details
          draw_details(@crawls[@selection])
        else
          draw_history
        end

        hint = @details ? "Up/Down: scroll | Enter/Left: back | q: quit" : "Up/Down: select | Enter: details | q: quit"
        draw_text(Curses.lines - 1, hint, Curses::A_REVERSE)
        @window.refresh
      end

      def draw_history
        visible_count = [Curses.lines - 5, 1].max
        max_start = [@crawls.length - visible_count, 0].max
        start = [[@selection - visible_count + 1, 0].max, max_start].min
        @crawls.slice(start, visible_count).each_with_index do |crawl, index|
          absolute_index = start + index
          marker = absolute_index == @selection ? "> " : "  "
          domains = Array(crawl[:domains]).join(", ")
          summary = "#{crawl[:created_at]}  #{domains}  pages: #{Array(crawl[:pages]).length}  files: #{Array(crawl[:files]).length}"
          draw_text(3 + index, "#{marker}#{summary}", absolute_index == @selection ? Curses::A_REVERSE : Curses::A_NORMAL)
        end
      end

      def draw_details(crawl)
        lines = [
          "Crawl: #{crawl[:id]}",
          "Created: #{crawl[:created_at]}",
          "Domains: #{Array(crawl[:domains]).join(', ')}",
          "Pages: #{Array(crawl[:pages]).length}  Files: #{Array(crawl[:files]).length}  Missing: #{Array(crawl[:missing]).length}",
          "Truncated at page limit: #{crawl[:truncated] ? 'yes' : 'no'}",
          "",
          "PAGES"
        ]
        lines.concat(Array(crawl[:pages]).map { |page| "  #{page[:url]}" })
        lines.concat(["", "FILES"])
        lines.concat(Array(crawl[:files]).map { |file| "  #{file[:url]} (#{file[:size]} bytes)" })
        lines.concat(["", "MISSING LINKS"])
        lines.concat(Array(crawl[:missing]).map { |missing| "  #{missing[:url]}" })

        visible_count = [Curses.lines - 4, 1].max
        max_offset = [lines.length - visible_count, 0].max
        @details_offset = [@details_offset, max_offset].min
        lines.slice(@details_offset, visible_count).each_with_index do |line, index|
          draw_text(2 + index, line, Curses::A_NORMAL)
        end
      end

      def draw_text(row, text, attribute)
        return if row.negative? || row >= Curses.lines || Curses.cols <= 0

        text = text.to_s[0, Curses.cols - 1]
        @window.setpos(row, 0)
        @window.attrset(attribute)
        @window.addstr(text)
        @window.attrset(Curses::A_NORMAL)
      end
    end
  end
end
