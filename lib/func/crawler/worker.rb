#Copyright (c) 2026 Nabil Ahmed

#Libraries
require 'net/http'
require 'uri'
require_relative 'tarantula'
require_relative 'pipeline/parser'




#Worker module to crawl the URL and extract data
module Worker
    class crawler

        #Intitialization of the crawler with input URLs
        def initialize(urls)
            @start_url = URI.parse(urls.first)
            host = @start_url.host
            @visited_urls = Set.new
            @queue = urls
        end
         
        #Main crawl method to process the URLs in the queue
        def crawl
            pages_crawled = 0
            while @queue.any?
                current_url = @queue.shift
                next if @visited_urls.include?(current_url)
                @visited_urls.add(current_url)
                html = fetch_page(current_url)
                if html
                    pages_crawled += 1
                    puts "Crawled: #{current_url}"
                    links = process_urls(html, current_url)
                    @queue.concat(links)
                end
                sleep(0.1)
            end
            puts "Total pages crawled: #{pages_crawled}"

        end

        
        def fetch_page(url)
        #Crawl logic to extract data from the URL
            begin
                uri = URI.parse(url)
                response = Net::Http.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
                    request = Net::HTTP::Get.new(uri)
                    request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3'
                    http.request(request)
                end
                if response.is_a?(Net::HTTPSuccess)
                    return response.body
                else
                    puts "Failed to fetch the URL: #{response.code} #{response.message}"
                end
            rescue StandardError => e
                puts "Error occurred while fetching the URL: #{e.message}"
                nil
            end    
                
        end
            
            
            

        def process_urls(html, current_url)
        #Parse the HTML and extract links
            begin
                links = []
                html.scan(/<a\s+(?:[^>]*?\s+)?href=(["'])(.*?)\1/) do |match|
                    link = match[1]
                    #Resolve relative URLs to absolute URLs
                    link = URI.join(current_url, link).to_s unless link =~ /\Ahttp/
                    links << link
                end
                return links.uniq
            rescue StandardError => e
                puts "Error occurred while processing the HTML: #{e.message}"
                []
            end
        end

            
    end
end

