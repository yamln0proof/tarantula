#Copyright (c) 2026 Nabil Ahmed

#Libraries
require 'net/http'
require 'uri'
require 'set'
require_relative '../../tarantula'
require_relative '../../config/db_management'
require_relative 'fetcher'
require_relative 'processor'





#Worker module to crawl the URL and extract data
module Worker
    class Crawler

        #Intitialization of the crawler with input URLs
        def initialize(urls, pages: nil)
            @visited_urls = Set.new
            @queue = urls

        end

        def run
            crawl
        end

        private
         
        #Main crawl method to process the URLs in the queue
        def crawl
            pages_crawled = 0
            while @queue.any?
                current_url = @queue.shift
                next if @visited_urls.include?(current_url)
                @visited_urls.add(current_url)
                html = Tarantula::Func::Fetcher.fetch(current_url)
                if html
                    links = Tarantula::Func::Crawler::Processor.process(html, current_url)
                    Tarantula::Config::Mongo.store_page(current_url, html)
                    Tarantula::Config::Mongo.store_request(current_url, html)
                    pages_crawled += 1
                    @queue.concat(links)
                end
                sleep(0.1)

            end

        end
            
    end
end
