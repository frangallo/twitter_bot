require 'openai'
require 'twitter'
require 'httparty'
require_relative 'openai_services'
require_relative 'twitter_service'
require_relative 'gospel_quote_service'


class GoseplDailyApplicationService

  def main
    puts 'Fetching the daily gospel...'
    gospel = fetch_gospel
    puts "Gospel: #{gospel[:text]}"

    puts 'Generate a daily application...'
    daily_application_prompt = "Create a concise and memorable daily applications from the gospel below using contemporary phrasing and vocabulary that is practical in nature. The daily application should be 200 characters or less. Draw inspiration from popular self-help or personal development concepts, while staying true to the gospel's teachings. Focus on personal growth, mental well-being, and community impact, incorporating an element of empowerment to engage the millennial audience. Keep the tone uplifting and optimistic. Only return the daily application, nothing else. And don't mention the work millenial. Gospel:\n#{gospel[:text]}"
    daily_application = gpt4_request(daily_application_prompt)


    puts 'Posting the tweet...'
    TwitterService.post_tweet_without_image(daily_application, "🤔 How Can You Incorporate Today's Gospel Into Your Life?")
    puts 'Tweet posted!'
    rescue StandardError => e
      Rails.logger.error "Error in main: #{e.message}"
      puts "Error in main: #{e.message}"
  end


  private

  def fetch_gospel
    GospelQuoteService.new.send(:fetch_gospel)
  end

  def gpt4_request(prompt)
    OpenaiServices::ChatgptService.call(prompt)
  end
end
