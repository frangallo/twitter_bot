require 'oauth'
require 'base64'

class TwitterService
  attr_reader :consumer_key, :consumer_secret, :access_token, :access_token_secret

  def initialize
    credentials = Rails.application.credentials[:twitter]
    @consumer_key = credentials[:api_key]
    @consumer_secret = credentials[:api_secret_key]
    @access_token = credentials[:access_token]
    @access_token_secret = credentials[:access_token_secret]
  end

  def upload_image(image_data)
    puts 'Original image_data encoding:'
    puts image_data.encoding

    consumer = OAuth::Consumer.new(consumer_key, consumer_secret, site: 'https://api.twitter.com')
    token = OAuth::AccessToken.new(consumer, access_token, access_token_secret)

    base64_image_data = Base64.strict_encode64(image_data)

    puts 'Base64 image_data encoding:'
    puts base64_image_data.encoding

    image_upload_response = token.post(
      'https://upload.twitter.com/1.1/media/upload.json',
      { media_data: base64_image_data },
      { 'Content-Type' => 'multipart/form-data', 'Content-Transfer-Encoding' => 'base64' }
    )

    if image_upload_response.code == '200'
      JSON.parse(image_upload_response.body)['media_id']
    else
      raise "Error uploading image: #{JSON.parse(image_upload_response.body)}"
    end
  end

  def post_tweet(quote, image_data)
    puts 'Uploading image...'
    media_id = upload_image(image_data)
    puts "Image uploaded. Media ID: #{media_id}"

    consumer = OAuth::Consumer.new(consumer_key, consumer_secret, site: 'https://api.twitter.com')
    token = OAuth::AccessToken.new(consumer, access_token, access_token_secret)
    quote_utf8 = quote.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')

    tweet_data = {
      "text": quote_utf8,
      "media": {
        "media_ids": [media_id.to_s]
      }
    }.to_json

    puts 'Posting tweet from inside post tweet...'
    tweet_post_response = token.post(
      'https://api.twitter.com/2/tweets',
      tweet_data,
      { 'Content-Type' => 'application/json' }
    )

    response_body = tweet_post_response.body.force_encoding('UTF-8')

    if tweet_post_response.code == '201'
      JSON.parse(response_body)['data']['id']
    else
      raise "Error posting tweet: #{JSON.parse(response_body)}"
    end
  end

  def post_summary_tweet_thread(gospel_summary)
    # Insert the newline character directly after the first sentence
    gospel_summary.sub!(/(\.|\?|\!)\s+/, "\\1\n\u200B\n\n")


    # Split the gospel_summary into sentences
    sentences = gospel_summary.split(/(?<=[.?!])\s+/)

    # Build tweet_chunks considering sentence boundaries and the 240-character limit
    tweet_chunks = []
    current_chunk = ""

    sentences.each do |sentence|
      if (current_chunk.length + sentence.length + 1) <= 240
        current_chunk << ' ' unless current_chunk.empty?
        current_chunk << sentence
      else
        tweet_chunks << current_chunk
        current_chunk = sentence
      end
    end
    tweet_chunks << current_chunk unless current_chunk.empty?

    # Create a reference to the previous tweet ID for threading
    previous_tweet_id = nil

    tweet_chunks.each do |chunk|
      # Prepare tweet_data with the chunk and in_reply_to_status_id (if available)
      tweet_data = {
        "text": chunk
      }

      if previous_tweet_id
        tweet_data["reply"] = { "in_reply_to_tweet_id": previous_tweet_id }
      end

      # Send the tweet and store its ID for threading
      tweet_post_response = post_single_tweet(tweet_data)
      previous_tweet_id = tweet_post_response['id']
    end
  end






  def post_single_tweet(tweet_data)
    consumer = OAuth::Consumer.new(consumer_key, consumer_secret, site: 'https://api.twitter.com')
    token = OAuth::AccessToken.new(consumer, access_token, access_token_secret)

    response = token.post(
      'https://api.twitter.com/2/tweets',
      tweet_data.to_json,
      { 'Content-Type' => 'application/json' }
    )

    response_body = response.body.force_encoding('UTF-8')

    if response.code == '201'
      JSON.parse(response_body)['data']
    else
      raise "Error posting tweet: #{JSON.parse(response_body)}"
    end
  end





  class << self
    def post_tweet(quote, image_data)
      new.post_tweet(quote, image_data)
    end

    def post_summary_tweet_thread(gospel_summary)
      new.post_summary_tweet_thread(gospel_summary)
    end
  end
end
