# frozen_string_literal: true

require "curses"
require "fileutils"
require "open3"
require "rubygems"
require "tmpdir"

module Tarantula
  module CLI
    class InstallScreen
      def self.run
        new.run
      end

      def run
        Curses.init_screen
        @screen_open = true
        @window = Curses.stdscr
        Curses.noecho
        Curses.cbreak
        Curses.curs_set(0)
        @window.keypad(true)

        draw_message("Building Tarantula and installing it for this user...")
        @success, @details = install
        draw_result
        wait_for_return
      ensure
        Curses.close_screen if @screen_open
      end

      private

      def install
        project_root = File.expand_path("../..", __dir__)
        gemspec_path = File.join(project_root, "tarantula.gemspec")
        executable_directory = File.join(Dir.home, ".local", "bin")

        Dir.mktmpdir("tarantula-install-") do |directory|
          package_path = File.join(directory, "tarantula.gem")
          output, status = Open3.capture2e(
            Gem.ruby, "-S", "gem", "build", gemspec_path, "--output", package_path,
            chdir: project_root
          )
          return [false, failure_details("Gem build failed", output)] unless status.success?

          FileUtils.mkdir_p(executable_directory)
          output, status = Open3.capture2e(
            Gem.ruby, "-S", "gem", "install", "--user-install", "--no-document",
            "--bindir", executable_directory, package_path
          )
          return [false, failure_details("Gem installation failed", output)] unless status.success?
        end

        [
          true,
          [
            "Tarantula was installed for this user.",
            "Command: #{File.join(executable_directory, 'tarantula')}",
            "Add #{executable_directory} to PATH to run: tarantula"
          ]
        ]
      rescue SystemCallError => error
        [false, ["Installation could not run: #{error.message}"]]
      end

      def failure_details(title, output)
        [title, *output.lines.map(&:strip).reject(&:empty?).last(6)]
      end

      def draw_result
        @window.clear
        draw_message(@success ? "Installation complete" : "Installation failed")
        @details.each_with_index do |line, index|
          draw_text(3 + index, line, @success ? Curses::A_NORMAL : Curses::A_BOLD)
        end
        draw_text(Curses.lines - 2, "Press Enter, q, or Esc to return to the menu", Curses::A_REVERSE)
        @window.refresh
      end

      def draw_message(message)
        @window.clear
        draw_text(1, "TARANTULA INSTALLER", Curses::A_REVERSE)
        draw_text(3, message, Curses::A_NORMAL)
        @window.refresh
      end

      def wait_for_return
        loop do
          key = @window.getch
          return if ["q", "Q", "\e", "\n", "\r", Curses::KEY_ENTER].include?(key)
        end
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
