require_relative 'openai_services'
require_relative 'gospel_quote_service'
require_relative 'twitter_service'

class GospelSummaryService
  def main
    puts 'Fetching the daily gospel...'
    gospel = fetch_gospel
    puts "Gospel: #{gospel[:text]}"

    puts 'Summarizing the daily gospel...'
    summary = summarize_gospel(gospel[:text])
    puts "Summary: #{summary}"

    # Prepend the first_tweet_text to the summary
    first_tweet_text = "✝️📖🙏🕊️ Today's Gospel Summary is from #{gospel[:verse]}. "
    summary_with_intro = first_tweet_text + summary

    puts 'Posting the gospel summary on Twitter...'
    TwitterService.post_summary_tweet_thread(summary_with_intro)
    puts 'Gospel summary posted!'
  rescue StandardError => e
    Rails.logger.error "Error in main: #{e.message}"
    puts "Error in main: #{e.message}"
  end

  private

  def fetch_gospel
    GospelQuoteService.new.send(:fetch_gospel)
  end

  def summarize_gospel(gospel)
    summary_prompt = "Create a Twitter thread summarizing the provided daily gospel passage in a way that is relatable and informative to millennials, with personal reflections or applications that illustrate the passage's message. Use concise language, avoid religious jargon, and keep the summary under 1200 characters. Incorporate relevant hashtags, tag relevant accounts, and use engaging visuals or media to increase visibility and engagement. Only return the summary, nothing else. :\n Gospel:\n#{gospel}"
    gpt4_request(summary_prompt)
  end

  def gpt4_request(prompt)
    OpenaiServices::ChatgptService.call(prompt)
  end
end
