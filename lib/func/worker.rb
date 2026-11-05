#Copyright (c) 2026 Nabil Ahmed

#URls from input/input file

@@URL = []
url = URL[0]



#Worker module to crawl the URL and extract data
module Worker
    class crawler
        class << self
            def crawl(url)
                @this_url = url
                #Code to crawl the URL and extract data
                puts "Crawling URL: #{this_url}"
                #Add your crawling logic here
            end

            
        end
    end
end

