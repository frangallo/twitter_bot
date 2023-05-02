# app/services/twitter_stream_listener.rb
require 'json'
require 'twilio-ruby'
require 'net/http'
require_relative 'twitter_service'
require_relative 'openai_services'


class TwitterStreamListener
  TARGET_USER_IDS = [1616902805402394628, 331498740,14931614, 21632108, 5577902, 12197852, 20545055, 16588111, 27500565, 47018380, 26483706, 22000517, 23721478, 403443988, 27379684, 36117822, 32150862, 4276531, 71715193, 32988140, 52150569, 20985527, 156012476, 33429434, 232252457, 34296240]
  KEYWORDS = ['Mass','Church','God','Christian','Lord','Christ','Love', 'love', 'Hope','hope', 'Father', 'pray', 'Jesus',
  "Genesis", "Exodus", "Leviticus", "Numbers",
  "Joshua", "Judges", "Job", "Psalms", "Proverbs",
  "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
  "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
  "Hebrews", "James", "Peter", "John", "Revelation"]


  def initialize
    @twitter_service = TwitterService.new
  end

  def listen_and_reply
    tweets = @twitter_service.fetch_tweets_from_users(TARGET_USER_IDS, KEYWORDS)

    if tweets.blank?
      puts "no matching tweets"
      return
    end

    unreplied_tweets = []
    replied = false

    # Shuffle the tweets to get a random order
    tweets.shuffle.each do |tweet|
      tweet_id = tweet['id']

      # If the tweet has not been replied to, reply and break the loop
      unless replied_to?(tweet_id)
        tweet_text = tweet['text']
        user_id = tweet['author_id']

        reply_text = generate_reply(tweet_text)

        if !daily_reply_limit_reached? && !replied
          puts "Replying to tweet ID: #{tweet_id}" # Added logging
          post_reply(user_id, tweet_id, reply_text)
          store_replied_tweet(tweet_id)
          replied = true
        else
          puts "Adding tweet ID: #{tweet_id} to unreplied_tweets" # Added logging
          unreplied_tweets << { url: "https://twitter.com/user/status/#{tweet_id}", reply: reply_text }
        end
      end
    end

    unless unreplied_tweets.empty?
      puts "Sending text message with unreplied tweets" # Added logging
      send_slack_notification_with_unreplied_tweets(unreplied_tweets)
    else
      puts "No unreplied tweets found" # Added logging
    end
  end



  private

  def send_slack_notification_with_unreplied_tweets(replies)
    webhook_url = Rails.application.credentials[:slack][:webhook_url]
    uri = URI.parse(webhook_url)

    message_body = "Unreplied Tweets and generated replies:\n\n"
    replies.each do |reply|
      message_body += "Tweet: #{reply[:url]}\nReply: #{reply[:reply]}\n\n"
    end

    payload = { text: message_body }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
    request.body = payload

    response = http.request(request)
    puts "Slack API response: #{response.code} #{response.message}"
  end

  def generate_reply(tweet_text)
    prompt = "Craft a thoughtful and relatable reply that someone on Twitter would post for to the following tweet.
    The audience of the tweet reply is millennials and the tweet should match the tone of the original tweet.
    Do not mention millennials in the reply and do not include hashtags. The reply should be less than 280 characters. Only return the reply, nothing else. Do not include the reply in quotations. Tweet: #{tweet_text}."
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
    TweetReply.where('created_at >= ?', Time.zone.now.beginning_of_day).count >= 0

  end

  def replied_to?(tweet_id)
    TweetReply.exists?(tweet_id: tweet_id)
  end

  def store_replied_tweet(tweet_id)
    TweetReply.create!(tweet_id: tweet_id)
  end
end
