require 'openai'
require 'twitter'

class GospelQuoteService
  def fetch_gospel
    url = 'https://www.vaticannews.va/en/word-of-the-day.html'
     response = HTTParty.get(url)
     parsed_page = Nokogiri::HTML(response.body)
     section_content = parsed_page.css('.section_content')[1]
     gospel_section = section_content.css('p')[1]
     gospel_text = gospel_section.inner_text.strip
     gospel_text
   rescue StandardError => e
     Rails.logger.error "Error fetching daily gospel: #{e.message}"
  end

  def gpt4_request(prompt)
    ChatgptService.call(prompt)
  end

  def generate_image(prompt)
    # Replace this with the actual DALL-E API implementation
    File.read('path/to/placeholder/image.png')
  end

  def post_tweet(quote, image_data)
    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = Rails.application.credentials.twitter[:api_key]  nOVhWS7cBTDRHwYqjRihaF3e1
      config.consumer_secret     = Rails.application.credentials.twitter[:api_secret_key] iyPSPhMoZKhxLoN91D7DzO1h2XrQhDTVq35YCbyYRrolyaTcrb
      config.access_token        = Rails.application.credentials.twitter[:access_token] 1256062256330223623-M7uOM7G3WzcYb9GTUud4XmJvS7uDQ8
      config.access_token_secret = Rails.application.credentials.twitter[:access_token_secret] FrSQ6xiVIb84fJVnA13s68sfj5Y0y6G8ziZGcrmd8quBR
    end

    media = client.upload(StringIO.new(image_data))
    client.update(quote, media_ids: [media.id])
  end

  def main
    gospel = fetch_gospel
    quotes_prompt = "Based on the following gospel, generate three motivational quotes that will go viral on Twitter:\n\n#{gospel}"
    quotes = gpt4_request(quotes_prompt)
    favorite_quote_prompt = "Choose your favorite quote from the following:\n\n#{quotes}"
    favorite_quote = gpt4_request(favorite_quote_prompt)
    description_prompt = "Describe the chosen quote so a text-to-image AI model can generate an image associated with it:\n\n#{favorite_quote}"
    quote_description = gpt4_request(description_prompt)
    image_data = generate_image(quote_description)
    post_tweet(favorite_quote, image_data)
  end
end
