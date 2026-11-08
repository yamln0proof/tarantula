#Copyright (c) 2026 Nabil Ahmed

require 'ferrum'
require '2captcha'

# Initialize the universal solver client
# Replace with your actual provider key (e.g., 2Captcha, CapMonster, SolveCaptcha)
module Tarantula
    class CaptchaSolver
        SOLVER_API_KEY = 'YOUR_API_KEY'
        client = TwoCaptcha.new(SOLVER_API_KEY)



        # STRATEGY A: Solving Traditional Image-Based CAPTCHAs

        def solve_image_captcha(browser, client, img_css_selector, input_css_selector)
        # 1. Take a screenshot of the specific element or download the image source
        captcha_element = browser.at_css(img_css_selector)
        captcha_element.screenshot(path: 'captcha.png')

        # 2. Upload to the solving service
        puts "Uploading image CAPTCHA..."
        result = client.normal('captcha.png')
        solution_text = result.text
        puts "Solved! Text: #{solution_text}"

        # 3. Inject text back into form input
        browser.at_css(input_css_selector).focus.type(solution_text)
    end

# STRATEGY B: Solving Modern Token-Based CAPTCHAs (reCAPTCHA v2/v3, Turnstile, etc.)        

        def solve_token_captcha(browser, client, target_url)
        # 1. Scrape the public identifier ("sitekey") embedded in the webpage
        # Look for reCAPTCHA site key inside the div container
  captcha_div = browser.at_css('div.g-recaptcha') || browser.at_css('div.h-captcha')
  sitekey = captcha_div.attribute('data-sitekey')

  puts "Found Sitekey: #{sitekey}"

  # 2. Ask the service to solve it by passing the sitekey and the exact page URL
  puts "Requesting bypass token..."
  result = client.recaptcha_v2(
    googlekey: sitekey,
    pageurl: target_url
  )
  token = result.text # This is the validation token returned by the solver


  browser.execute("document.getElementById('g-recaptcha-response').innerHTML = '#{token}';")
  

end

# Execution Flow

begin
  target_url = 'https://example.com'
  browser.go_to(target_url)

  # Check what type of captcha is present and run execution
  if browser.at_css('div.g-recaptcha')
    solve_token_captcha(browser, client, target_url)
  elsif browser.at_css('#captcha-img')
    solve_image_captcha(browser, client, '#captcha-img', '#captcha-input-field')
  end

  # Submit the form
  browser.at_css('#submit-btn').click
  puts "Form submitted successfully."
ensure
  browser.quit
end

