require 'openai'
require 'twitter'
require 'httparty'
require_relative 'openai_services'
require_relative 'twitter_service'


class MantraService

  def main
    puts 'Generate a mantra...'
    mantra_prompt = "Create 3 concise, memorable Bible-inspired mantra using contemporary phrasing and vocabulary that is practical in nature. Draw inspiration from popular self-help or personal development concepts, while staying true to biblical teachings. Focus on personal growth, mental well-being, and community impact, incorporating an element of empowerment to engage the millennial audience. Keep the tone uplifting and optimistic. Only return the mantras, nothing else"
    mantras = gpt4_request(mantra_prompt)

    puts 'Selecting a favorite mantra...'
    favorite_mantra_prompt = "Choose your favorite mantra that will go viral on Twitter from the following mantras. Only return your favorite mantra, nothing else. Do not include the mantra in quotations :\n Mantras:\n#{mantras}"
    favorite_mantra = gpt4_request(favorite_mantra_prompt)
    puts "Favorite Mantra: #{favorite_mantra}"

    puts 'Posting the tweet...'
    TwitterService.post_tweet_without_image(favorite_mantra)
    puts 'Tweet posted!'
    rescue StandardError => e
      Rails.logger.error "Error in main: #{e.message}"
      puts "Error in main: #{e.message}"
  end


  private

  def gpt4_request(prompt)
    OpenaiServices::ChatgptService.call(prompt)
  end
end
