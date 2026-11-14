# frozen_string_literal: true

require "curses"

module Tarantula
  module CLI
    class SettingsScreen
      FIELDS = [
        { key: :open_timeout, label: "HTTP open timeout (seconds)" },
        { key: :read_timeout, label: "HTTP read timeout (seconds)" },
        { key: :max_redirects, label: "Maximum redirects" },
        { key: :max_html_bytes, label: "Maximum HTML size (bytes)" },
        { key: :requests_per_minute, label: "Requests per minute (0 = unlimited)" },
        { key: :custom_header, label: "Custom HTTP header (Name: Value)" },
        { key: :database_path, label: "Crawl database path" },
        { key: :captcha_threshold, label: "CAPTCHA detection threshold (0-1)" }
      ].freeze

      def self.run(settings:)
        new(settings: settings).run
      end

      def initialize(settings:)
        @settings = settings
        @selection = 0
        @edit_value = nil
        @message = nil
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
      end

      def event_loop
        loop do
          draw_screen
          key = normalize_key(@window.getch)
          if @edit_value
            handle_edit_key(key)
          else
            return if handle_navigation_key(key) == :back
          end
        end
      end

      def handle_navigation_key(key)
        case key
        when Curses::KEY_UP, "k", "K"
          @selection = (@selection - 1) % FIELDS.length
          @message = nil
        when Curses::KEY_DOWN, "j", "J"
          @selection = (@selection + 1) % FIELDS.length
          @message = nil
        when Curses::KEY_ENTER, "\n", "\r"
          begin_edit
        when "q", "Q", "\e"
          :back
        end
      end

      def handle_edit_key(key)
        case key
        when Curses::KEY_ENTER, "\n", "\r"
          save_edit
        when "\e"
          @edit_value = nil
          @message = "Change cancelled."
        when "\b", "\u007f", Curses::KEY_BACKSPACE
          @edit_value.chop!
        when "\u0015"
          @edit_value.clear
        when String
          @edit_value << key if key.match?(/\A[[:print:]]\z/) && @edit_value.length < 512
        end
      end

      def begin_edit
        field = FIELDS.fetch(@selection)
        @edit_value = @settings[field[:key]].to_s.dup
        @message = "Enter a new value, then press Enter."
      end

      def save_edit
        field = FIELDS.fetch(@selection)
        @settings.update(field[:key], @edit_value)
        @edit_value = nil
        @message = "Setting updated for this session."
      rescue ArgumentError => error
        @message = error.message
      end

      def draw_screen
        @window.clear
        draw_text(1, "TARANTULA - SETTINGS", color(1))
        draw_text(3, "Settings apply only until the application exits.", Curses::A_NORMAL)

        FIELDS.each_with_index do |field, index|
          value = if index == @selection && @edit_value
                    "#{@edit_value}_"
                  else
                    @settings[field[:key]].to_s
                  end
          marker = index == @selection ? "> " : "  "
          draw_text(5 + index * 2, "#{marker}#{field[:label]}: #{value}", index == @selection ? color(2) : Curses::A_NORMAL)
        end

        draw_text(Curses.lines - 4, @message, @message&.start_with?("Invalid") ? color(3) : Curses::A_NORMAL) if @message
        hint = @edit_value ? "Enter: save | Esc: cancel | Ctrl+U: clear" : "Up/Down: select | Enter: edit | q/Esc: back"
        draw_text(Curses.lines - 2, hint, Curses::A_REVERSE)
        @window.refresh
      end

      def normalize_key(key)
        key.is_a?(Integer) && key.between?(0, 127) ? key.chr : key
      end

      def draw_text(row, text, attribute)
        return if row.negative? || row >= Curses.lines || Curses.cols <= 0

        text = text.to_s[0, Curses.cols - 1]
        @window.setpos(row, 0)
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
