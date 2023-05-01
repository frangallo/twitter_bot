require_relative 'openai_services'
require_relative 'gospel_quote_service'
require_relative 'twitter_service'
require "json"

class GospelSummaryService
  def main
    puts 'Fetching the daily gospel...'
    gospel = fetch_gospel
    puts "Gospel: #{gospel[:text]}"

    puts 'Summarizing the daily gospel...'
    first_tweet_text = "✝️📖🙏🕊️ Today's Gospel Summary is from #{gospel[:verse]}:"
    summary = summarize_gospel(gospel[:text], first_tweet_text)
    puts "Summary: #{summary}"
    gospel_summary_lines = JSON.parse(summary)

    puts 'Posting the gospel summary on Twitter...'
    TwitterService.post_summary_tweet_thread(gospel_summary_lines, first_tweet_text)
    puts 'Gospel summary posted!'
  rescue StandardError => e
    Rails.logger.error "Error in main: #{e.message}"
    puts "Error in main: #{e.message}"
  end

  private

  def fetch_gospel
    GospelQuoteService.new.send(:fetch_gospel)
  end

  def summarize_gospel(gospel, first_tweet_text)
    summary_prompt = "Create a Twitter thread summarizing the provided daily gospel passage in a way that is relatable and informative to millennials, with personal reflections or applications that illustrate the passage's message. Use concise language, avoid religious jargon, keep the summary under 1200 characters and start each tweet using a number/slash format (e.g. 1/). Incorporate relevant hashtags to increase visibility and engagement but only use one hashtag per tweet. Don't include the word millenial in the thread. The first tweet should start with #{first_tweet_text}. The first tweet in the thread should be under 275 characters, every other tweet in the thead should be under 280 characters. Return an array with each tweet as an element. The array should not be a string. Don't return anything else besides the array. :\n Gospel:\n#{gospel}"
    gpt4_request(summary_prompt)
  end

  def gpt4_request(prompt)
    OpenaiServices::ChatgptService.call(prompt)
  end
end
