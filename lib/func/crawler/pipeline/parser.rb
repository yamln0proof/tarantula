require 'uri'
require 'curses'

class Parser
    def urls_input(url)
        
        urls = nil
        if ARGV[0] && FILE.exist?(ARGV[0])
            begin
                urls = File.readlines(ARGV[0]).map(&:strip).reject(&:empty?)
            rescue StandardError => e
                puts "Error reading file: #{e.message}"
        end

    end
end
