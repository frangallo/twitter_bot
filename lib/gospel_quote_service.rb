require 'openai'
require 'twitter'
require 'httparty'
require_relative 'openai_services'
require_relative 'twitter_service'


class GospelQuoteService

  def main
    puts 'Fetching the daily gospel...'
    gospel = fetch_gospel
    puts "Gospel: #{gospel[:text]}"

    puts 'Generating motivational quotes...'
    quotes_prompt = "Generate 3 inspiring quotes based on the provided daily Catholic gospel, tailored for millennials and younger generations to relate to and share on Twitter. The quotes should vary in tone and style, including casual, inspirational, modern, and reflective elements as appropriate for the message. Do not include any hashtags. Only return the quotes. :\n Gospel:\n#{gospel[:text]}"
    quotes = gpt4_request(quotes_prompt)
    puts "Quotes: #{quotes.inspect}"

    puts 'Selecting a favorite quote...'
    favorite_quote_prompt = "Choose your favorite quote that will go viral on Twitter from the following quotes. Only return your favorite quote. Nothing else. Do not include the quote in quotations :\n Quotes:\n#{quotes}"
    favorite_quote = gpt4_request(favorite_quote_prompt)
    puts "Favorite Quote: #{favorite_quote}"

    puts 'Generating a description for the image...'
    description_prompt = "Provide a specific and detailed description of the given quote for a text-to-image AI model to generate a digital art, 4K image associated with it. The description should be less than 400 characters and avoid asking the text-to-image AI model to generate images with words or hands in it. The description should also avoid describing facial expressions and should not include the quote in it or reference the quote. In the description, specify the type of colors (warm, vibrant, etc.), the type of image (digital painting, oil painting, etc.), and the resolution that best represent the quote. Only return the description. Nothing else. :\n Quote :\n#{favorite_quote}"
    quote_description = gpt4_request(description_prompt)
    puts "Image Description: #{quote_description}"

    puts 'Generating an image...'
    image_data = dalle_request(quote_description)

    puts 'Posting the tweet...'
    TwitterService.post_tweet(favorite_quote, image_data)
    puts 'Tweet posted!'
    rescue StandardError => e
      Rails.logger.error "Error in main: #{e.message}"
      puts "Error in main: #{e.message}"
  end

  def fetch_gospel
    url = 'https://bible.usccb.org/daily-bible-reading'
    parsed_page = fetch_page(url)
    gospel_header = find_gospel_header(parsed_page)

    if gospel_header
      content_body = find_gospel(gospel_header, 'content-body')
      gospel_verse = find_gospel_verse(gospel_header, 'address')
    end

    if content_body
      gospel_text = content_body.inner_text.strip
      {verse: gospel_verse, text: gospel_text }
    else
      Rails.logger.error "Error fetching daily gospel: content_body not found"
      nil
    end
    rescue StandardError => e
      Rails.logger.error "Error fetching daily gospel: #{e.message}"
      nil
  end

  private

  def fetch_page(url)
    response = HTTParty.get(url)
    Nokogiri::HTML(response.body)
  end

  def find_gospel_header(parsed_page)
    parsed_page.css('.name').find { |header| header.content.match?(/^\s*Gospel\s*$/) }
  end

  def find_gospel(header, html_class)
    current_node = header.parent
    while current_node = current_node.next_element
      return current_node if current_node['class'] == html_class
    end

    nil
  end

  def find_child_with_class(parent, class_name)
    parent.children.find { |child| child['class'] == class_name }
  end

  def find_gospel_verse(header, class_name)
    address_node = find_child_with_class(header.parent, class_name)
    return address_node.inner_text.strip if address_node

    nil
  end


  def gpt4_request(prompt)
    OpenaiServices::ChatgptService.call(prompt)
  end

  def dalle_request(prompt)
    OpenaiServices::DalleService.call(prompt)
  end

end
