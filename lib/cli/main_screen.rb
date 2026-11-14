#Copyright (c) 2026 Nabil Ahmed
# frozen_string_literal: true

require "curses"
require "set"
require_relative "../func/crawler/worker"
require_relative "../config/crawl_database"
require_relative "../config/crawl_report_exporter"
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
        @live_mutex = Mutex.new
        @live_links = []
        @live_files = []
        @live_link_urls = Set.new
        @live_file_urls = Set.new
        @live_scroll_offset = 0
      end

      def run
        Curses.init_screen
        @screen_open = true
        @window = Curses.stdscr
        resize_window
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

          if key == Curses::KEY_RESIZE
            resize_window
            next
          end

          if @working
            case key
            when Curses::KEY_UP, "k", "K"
              @live_scroll_offset += 1
            when Curses::KEY_DOWN, "j", "J"
              @live_scroll_offset = [@live_scroll_offset - 1, 0].max
            when "s", "S"
              unless @stop_requested
                @crawler.stop
                @stop_requested = true
              end
            end
            next
          end

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

      def resize_window
        rows = Curses.lines
        columns = Curses.cols
        return if rows <= 0 || columns <= 0

        @window.resize(rows, columns)
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
        @stop_requested = false
        @animation_frame = 0
        @live_scroll_offset = 0
        @live_mutex.synchronize do
          @live_links.clear
          @live_files.clear
          @live_link_urls.clear
          @live_file_urls.clear
        end
        @crawler = if domain_input.start_with?("@")
                     domains_file = domain_input.delete_prefix("@").strip
                     raise ArgumentError, "Enter a domain file path after @." if domains_file.empty?

                     Worker::Crawler.new(domains_file: domains_file, settings: @settings,
                                         on_update: method(:record_live_update))
                   else
                     Worker::Crawler.new(domain_input.split(","), settings: @settings,
                                         on_update: method(:record_live_update))
                   end
        @crawl_thread = Thread.new do
          begin
            result = @crawler.run
            database = @database || Tarantula::Config::CrawlDatabase.new(path: @settings[:database_path])
            crawl = database.store_crawl(domains: result.fetch(:domains), result: result)
            begin
              report_paths = Tarantula::Config::CrawlReportExporter.new.export(crawl)
              { result: result, crawl_id: crawl.fetch(:id), report_paths: report_paths }
            rescue IOError, SystemCallError, JSON::GeneratorError => e
              { result: result, crawl_id: crawl.fetch(:id), report_error: e.message }
            end
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
        @report_paths = outcome[:report_paths]
        @report_error = outcome[:report_error]
        @error = outcome[:error]
        @stop_requested = false
        @crawler = nil
        @working = false
        @crawl_thread = nil
      end

      def record_live_update(type, item)
        @live_mutex.synchronize do
          case type
          when :page, :link
            next unless @live_link_urls.add?(item[:url])

            @live_links << { url: item[:url], kind: type == :page ? :page : item[:kind] }
          when :file
            next unless @live_file_urls.add?(item[:url])

            @live_files << item
          end
        end
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
          status = if @stop_requested
                     "Stopping after current request... | Up/Down: scroll"
                   else
                     "Crawling... s: stop | Up/Down: scroll"
                   end
          draw_text(13, "#{frame} #{status}", Curses::A_NORMAL)
          draw_live_activity
        else
          draw_text(13, "Tab/Up/Down: switch field | Enter: crawl | Esc/q: back", Curses::A_NORMAL)
        end

        @window.refresh
      end

      def draw_live_activity
        links, files = @live_mutex.synchronize { [@live_links.dup, @live_files.dup] }
        top = 14
        bottom = Curses.lines - 1
        height = bottom - top + 1
        return if height < 4

        if Curses.cols >= 80
          column_gap = 3
          column_width = (Curses.cols - column_gap) / 2
          draw_live_box(top, 0, column_width, height, "DISCOVERED LINKS", links) do |item|
            "#{item[:kind]}: #{item[:url]}"
          end
          files_column = column_width + column_gap
          draw_live_box(top, files_column, Curses.cols - files_column, height, "FILES", files) do |file|
            "#{file[:url]} (#{file[:size]} bytes)"
          end
        else
          box_height = (height - 1) / 2
          draw_live_box(top, 0, Curses.cols, box_height, "DISCOVERED LINKS", links) do |item|
            "#{item[:kind]}: #{item[:url]}"
          end
          files_top = top + box_height + 1
          draw_live_box(files_top, 0, Curses.cols, bottom - files_top + 1, "FILES", files) do |file|
            "#{file[:url]} (#{file[:size]} bytes)"
          end
        end
      end

      def draw_live_box(top, left, width, height, title, items)
        return if top.negative? || width < 4 || height < 4 || top + height > Curses.lines

        right = left + width - 1
        bottom = top + height - 1
        draw_text(top, "+#{'-' * (width - 2)}+", Curses::A_NORMAL, left)
        draw_text(bottom, "+#{'-' * (width - 2)}+", Curses::A_NORMAL, left)
        (top + 1...bottom).each do |row|
          draw_text(row, "|", Curses::A_NORMAL, left)
          draw_text(row, "|", Curses::A_NORMAL, right)
        end
        draw_text(top + 1, "#{title} (#{items.length})"[0, width - 2], Curses::A_BOLD, left + 1)

        content_rows = height - 3
        return if content_rows <= 0

        lines = visible_live_lines(items, width - 2, content_rows) { |item| yield(item) }
        lines.each_with_index do |line, index|
          draw_text(top + index + 2, line, Curses::A_NORMAL, left + 1)
        end
      end

      def visible_live_lines(items, width, row_limit)
        offset = @live_scroll_offset
        recent_lines = []

        items.reverse_each do |item|
          wrapped_lines = yield(item).to_s.chars.each_slice(width).map(&:join)
          if offset >= wrapped_lines.length
            offset -= wrapped_lines.length
            next
          end

          visible_lines = wrapped_lines.first(wrapped_lines.length - offset)
          offset = 0
          visible_lines.reverse_each do |line|
            recent_lines << line
            break if recent_lines.length == row_limit
          end
          break if recent_lines.length == row_limit
        end

        recent_lines.reverse
      end

      #Result box
      def draw_result
        draw_text(13, "Crawl completed and saved.", color(4))
        draw_text(14, "Pages: #{@result[:pages].length}  Files: #{@result[:files].length}  Missing: #{@result[:missing].length}", Curses::A_NORMAL)
        draw_text(15, "Crawl ID: #{@crawl_id}", Curses::A_NORMAL)
        draw_text(16, "Stopped because a CAPTCHA was detected.", color(3)) if @result[:stopped_for_captcha]
        draw_text(16, "Crawl stopped by user.", color(3)) if @result[:stopped_by_user]
        errors = Array(@result[:errors])
        draw_text(17, "Crawl errors: #{errors.length}", errors.empty? ? Curses::A_NORMAL : color(3))
        if @report_error
          draw_text(18, "Report export failed: #{@report_error}", color(3))
        elsif @report_paths
          draw_text(18, "Reports saved in: ./reports", Curses::A_NORMAL)
        end
        draw_text(19, "#{errors.first[:url]}: #{errors.first[:error]}", color(3)) unless errors.empty?

        preview = @result[:pages].first(3).map { |page| page[:url] }
        preview.first(2).each_with_index { |url, index| draw_text(20 + index, url, Curses::A_NORMAL) }
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

      def draw_text(row, text, attribute, column = 0)
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
