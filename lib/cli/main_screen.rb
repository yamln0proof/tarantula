#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true

require "curses"
require_relative "../func/crawler/worker"
require_relative "../config/crawl_database"
require_relative "../config/settings"

module Tarantula
  module CLI
    class MainScreen
      SPINNER_FRAMES = ["|", "/", "-", "\\"].freeze
      FIELDS = [
        { name: :domains, label: "Domains (comma-separated or @file)" }
      ].freeze

      def self.run(database: nil, settings: Tarantula::Config::Settings.new)
        new(database: database, settings: settings).run
      end

      def initialize(database: nil, settings: Tarantula::Config::Settings.new)
        @database = database
        @settings = settings
        @values = { domains: String.new }
        @active_field = 0
        @result = nil
        @error = nil
      end

      def run
        Curses.init_screen
        @screen_open = true
        @window = Curses.stdscr
        setup_terminal
        event_loop
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
        Curses.init_pair(2, Curses::COLOR_BLACK, Curses::COLOR_CYAN)
        Curses.init_pair(3, Curses::COLOR_RED, Curses::COLOR_BLACK)
        Curses.init_pair(4, Curses::COLOR_GREEN, Curses::COLOR_BLACK)
      end

      def event_loop
        loop do
          finish_crawl_if_ready
          @window.timeout = @working ? 100 : -1
          draw_screen
          key = normalize_key(@window.getch)

          next if @working

          if @result
            return :back if ["q", "Q", "\e", "\n", "\r", Curses::KEY_ENTER].include?(key)

            next
          end

          case key
          when "\t", Curses::KEY_DOWN, Curses::KEY_UP
            @active_field = (@active_field + 1) % FIELDS.length
          when "\n", "\r", Curses::KEY_ENTER
            run_crawl
          when "\e", "q", "Q"
            return :back
          when "\b", "\u007f", Curses::KEY_BACKSPACE
            remove_character
          when "\u0015"
            @values.fetch(FIELDS[@active_field][:name]).clear
          when String
            append_character(key) if printable_character?(key)
          end
        end
      end

      def normalize_key(key)
        key.is_a?(Integer) && key.between?(0, 127) ? key.chr : key
      end

      def printable_character?(key)
        key.match?(/\A[[:print:]]\z/)
      end

      def append_character(character)
        value = @values.fetch(FIELDS[@active_field][:name])
        value << character if value.length < 240
        @error = nil
      end

      def remove_character
        value = @values.fetch(FIELDS[@active_field][:name])
        value.chop!
        @error = nil
      end

      #Crawl method, not sure why it is here :)
      def run_crawl
        domain_input = @values[:domains].strip
        raise ArgumentError, "Enter at least one domain." if domain_input.empty?

        @error = nil
        @working = true
        @animation_frame = 0
        @crawl_thread = Thread.new do
          begin
            result = if domain_input.start_with?("@")
                       domains_file = domain_input.delete_prefix("@").strip
                       raise ArgumentError, "Enter a domain file path after @." if domains_file.empty?

                       Worker::Crawler.new(domains_file: domains_file, settings: @settings).run
                     else
                       Worker::Crawler.new(domain_input.split(","), settings: @settings).run
                     end
            database = @database || Tarantula::Config::CrawlDatabase.new(path: @settings[:database_path])
            crawl = database.store_crawl(domains: result.fetch(:domains), result: result)
            { result: result, crawl_id: crawl.fetch(:id) }
          rescue ArgumentError, Errno::ENOENT, Errno::EACCES, IOError => e
            { error: e.message }
          end
        end
        @crawl_thread.report_on_exception = false
      rescue ArgumentError, Errno::ENOENT, Errno::EACCES, IOError => e
        @working = false
        @error = e.message
      end

      def finish_crawl_if_ready
        thread = @crawl_thread
        return unless thread && !thread.alive?

        outcome = thread.value
        @result = outcome[:result]
        @crawl_id = outcome[:crawl_id]
        @error = outcome[:error]
        @working = false
        @crawl_thread = nil
      end

      #Crawling screen
      def draw_screen
        @window.clear
        draw_centered(1, "TARANTULA - CRAWL", color(1))
        draw_centered(3, "Live HTTP(S) Crawl ;)", Curses::A_NORMAL)

        FIELDS.each_with_index do |field, index|
          row = 6 + index * 3
          draw_text(row, field[:label], Curses::A_NORMAL)
          attribute = index == @active_field && !@result ? color(2) : Curses::A_REVERSE
          draw_text(row + 1, field_value(field[:name]), attribute)
        end

        if @error
          draw_text(13, "Error: #{@error}", color(3))
        elsif @result
          draw_result
        elsif @working
          frame = SPINNER_FRAMES[@animation_frame % SPINNER_FRAMES.length]
          @animation_frame += 1
          draw_text(13, "#{frame} Crawling happening...", Curses::A_NORMAL)
        else
          draw_text(13, "Tab/Up/Down: switch field | Enter: crawl | Esc/q: back", Curses::A_NORMAL)
        end

        @window.refresh
      end

      #Result box
      def draw_result
        draw_text(13, "Crawl completed and saved.", color(4))
        draw_text(14, "Pages: #{@result[:pages].length}  Files: #{@result[:files].length}  Missing: #{@result[:missing].length}", Curses::A_NORMAL)
        draw_text(16, "Stopped because a CAPTCHA was detected.", color(3)) if @result[:stopped_for_captcha]
        errors = Array(@result[:errors])
        draw_text(17, "Crawl errors: #{errors.length}", errors.empty? ? Curses::A_NORMAL : color(3))
        draw_text(18, "#{errors.first[:url]}: #{errors.first[:error]}", color(3)) unless errors.empty?
        draw_text(15, "Crawl ID: #{@crawl_id}", Curses::A_NORMAL)

        preview = @result[:pages].first(3).map { |page| page[:url] }
        preview.each_with_index { |url, index| draw_text(19 + index, url, Curses::A_NORMAL) }
        draw_text(Curses.lines - 2, "Press Enter, q, or Esc to return to the menu", Curses::A_REVERSE)
      end

      def field_value(name)
        value = @values.fetch(name)
        active = FIELDS[@active_field][:name] == name && !@result
        text = active ? "#{value}_" : value
        available = [Curses.cols - 4, 4].max
        text.length > available ? "...#{text[-(available - 3), available - 3]}" : text
      end

      def draw_centered(row, text, attribute)
        return if Curses.cols <= 0

        text = text[0, Curses.cols]
        draw_text(row, text, attribute, [(Curses.cols - text.length) / 2, 0].max)
      end

      def draw_text(row, text, attribute, column = 2)
        return if row.negative? || row >= Curses.lines || column >= Curses.cols

        text = text.to_s[0, Curses.cols - column]
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
