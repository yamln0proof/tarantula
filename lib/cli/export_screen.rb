# frozen_string_literal: true

require "curses"
require_relative "../config/crawl_database"
require_relative "../config/crawl_report_exporter"

module Tarantula
  module CLI
    class ExportScreen
      def self.run(database: nil, database_path: Tarantula::Config::CrawlDatabase::DEFAULT_PATH)
        database ||= Tarantula::Config::CrawlDatabase.new(path: database_path)
        new(database: database).run
      end

      def initialize(database:)
        @database = database
        @exporter = Tarantula::Config::CrawlReportExporter.new
        @directory = File.join(Dir.pwd, "reports")
        @selection = 0
        @message = nil
        @editing_directory = false
      end

      def run
        @crawls = @database.recent_crawls
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
          key = normalize_key(@window.getch)
          if @editing_directory
            handle_directory_key(key)
          else
            return if handle_navigation_key(key) == :back
          end
        end
      end

      def handle_navigation_key(key)
        case key
        when Curses::KEY_UP, "k", "K"
          @selection = [@selection - 1, 0].max unless @crawls.empty?
        when Curses::KEY_DOWN, "j", "J"
          @selection = [@selection + 1, @crawls.length - 1].min unless @crawls.empty?
        when "d", "D"
          begin_directory_edit
        when "e", "E", Curses::KEY_ENTER, "\n", "\r"
          export_selected
        when "q", "Q", "\e"
          :back
        end
      end

      def begin_directory_edit
        @directory_edit_buffer = @directory.dup
        @editing_directory = true
        @message = "Edit the destination directory, then press Enter."
      end

      def handle_directory_key(key)
        case key
        when Curses::KEY_ENTER, "\n", "\r"
          @directory = @directory_edit_buffer
          @editing_directory = false
          @message = "Destination directory updated."
        when "\e"
          @editing_directory = false
          @message = "Directory edit cancelled."
        when "\b", "\u007f", Curses::KEY_BACKSPACE
          @directory_edit_buffer.chop!
        when "\u0015"
          @directory_edit_buffer.clear
        when String
          @directory_edit_buffer << key if key.match?(/\A[[:print:]]\z/) && @directory_edit_buffer.length < 512
        end
      end

      def export_selected
        if @crawls.empty?
          @message = "There are no saved crawls to export."
          return
        end
        if @directory.strip.empty?
          @message = "Destination directory cannot be empty."
          return
        end

        path = @exporter.export_text(@crawls.fetch(@selection), directory: @directory)
        @message = "Report exported: #{path}"
      rescue ArgumentError, IOError, SystemCallError => error
        @message = "Export failed: #{error.message}"
      end

      def draw_screen
        @window.clear
        draw_text(0, "TARANTULA - EXPORT REPORT", Curses::A_REVERSE)
        draw_text(1, "-" * [Curses.cols - 1, 0].max, Curses::A_NORMAL)

        if @crawls.empty?
          draw_text(3, "No saved crawls to export.", Curses::A_NORMAL)
        else
          draw_crawls
        end

        directory_value = @editing_directory ? @directory_edit_buffer : @directory
        marker = @editing_directory ? " (editing)" : ""
        draw_text(Curses.lines - 5, "Directory#{marker}: #{directory_value}", Curses::A_NORMAL)
        draw_text(Curses.lines - 3, @message, Curses::A_NORMAL) if @message
        hint = @editing_directory ? "Enter: save | Esc: cancel | Ctrl+U: clear" :
          "Up/Down: select | d: directory | e/Enter: export TXT | q: back"
        draw_text(Curses.lines - 1, hint, Curses::A_REVERSE)
        @window.refresh
      end

      def draw_crawls
        visible_count = [Curses.lines - 8, 1].max
        max_start = [@crawls.length - visible_count, 0].max
        start = [[@selection - visible_count + 1, 0].max, max_start].min
        @crawls.slice(start, visible_count).each_with_index do |crawl, index|
          absolute_index = start + index
          marker = absolute_index == @selection ? "> " : "  "
          summary = "#{crawl[:created_at]}  #{Array(crawl[:domains]).join(', ')}  " \
                    "pages: #{Array(crawl[:pages]).length}  files: #{Array(crawl[:files]).length}"
          attribute = absolute_index == @selection ? Curses::A_REVERSE : Curses::A_NORMAL
          draw_text(3 + index, "#{marker}#{summary}", attribute)
        end
      end

      def normalize_key(key)
        key.is_a?(Integer) && key.between?(0, 127) ? key.chr : key
      end

      def draw_text(row, text, attribute)
        return if row.negative? || row >= Curses.lines || Curses.cols <= 0

        @window.setpos(row, 0)
        @window.attrset(attribute)
        @window.addstr(text.to_s[0, Curses.cols - 1])
        @window.attrset(Curses::A_NORMAL)
      end
    end
  end
end
