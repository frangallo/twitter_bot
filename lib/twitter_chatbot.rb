# app/services/twitter_stream_listener.rb
require 'json'
require_relative 'twitter_service'
require_relative 'openai_services'

class TwitterStreamListener
  TARGET_USER_IDS = [5577902, 12197852, 20545055, 16588111, 27500565, 47018380, 26483706, 22000517, 23721478, 403443988]
  KEYWORDS = ['God', 'Love', 'love', 'Hope','hope', 'Father', 'pray', 'Jesus',
  "Genesis", "Exodus", "Leviticus", "Numbers",
  "Joshua", "Judges", "Job", "Psalms", "Proverbs",
  "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations",
  "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
  "Hebrews", "James", "Peter", "John", "Jude", "Revelation"]


  def initialize
    @twitter_service = TwitterService.new
  end

  def listen_and_reply
    return if daily_reply_limit_reached?

    tweets = @twitter_service.fetch_tweets_from_users(TARGET_USER_IDS, KEYWORDS)
    return if tweets.empty?

    # Shuffle the tweets to get a random order
    tweets.shuffle.each do |tweet|
      tweet_id = tweet['id']

      # If the tweet has not been replied to, reply and break the loop
      unless replied_to?(tweet_id)
        tweet_text = tweet['text']
        user_id = tweet['author_id']

        reply_text = generate_reply(tweet_text)
        post_reply(user_id, tweet_id, reply_text)
        store_replied_tweet(tweet_id)

        # Break the loop after replying
        break
      end
    end
  end

  private

  def generate_reply(tweet_text)
    prompt = "Craft a thoughtful and relatable reply that someone on Twitter would post for to the following tweet.
    The audience of the tweet reply is millennials and the tweet should match the tone of the original tweet.
    Do not mention millennials in the reply and do not include hashtags. Only return the reply, nothing else. Do not include the reply in quotations. Tweet: #{tweet_text}."
    OpenaiServices::ChatgptService.call(prompt)
  end

  def post_reply(user_id, tweet_id, reply_text)
    reply_data = {
      "text": "#{reply_text}",
      "reply": { "in_reply_to_tweet_id": tweet_id }
    }

    @twitter_service.post_single_tweet(reply_data)
  end

  def daily_reply_limit_reached?
    TweetReply.where('created_at >= ?', Time.zone.now.beginning_of_day).count >= 20

  end

  def replied_to?(tweet_id)
    TweetReply.exists?(tweet_id: tweet_id)
  end

  def store_replied_tweet(tweet_id)
    TweetReply.create!(tweet_id: tweet_id)
end
end
