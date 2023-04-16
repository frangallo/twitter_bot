require 'oauth'
require 'base64'
require 'typhoeus'

class TwitterService
  attr_reader :consumer_key, :consumer_secret, :access_token, :access_token_secret, :consumer, :token, :bearer_token


  def initialize
    credentials = Rails.application.credentials[:twitter]
    @consumer_key = credentials[:api_key]
    @consumer_secret = credentials[:api_secret_key]
    @access_token = credentials[:access_token]
    @access_token_secret = credentials[:access_token_secret]
    @bearer_token = credentials[:bearer_token]
    @consumer = OAuth::Consumer.new(consumer_key, consumer_secret, site: 'https://api.twitter.com')
    @token = OAuth::AccessToken.new(consumer, access_token, access_token_secret)
  end

  def upload_image(image_data)
    puts 'Original image_data encoding:'
    puts image_data.encoding

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

  def post_tweet_without_image(text)
  text_utf8 = "Today's Mantra\n\n\u200B\n\n" + text.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')

  tweet_data = {
    "text": text_utf8
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


  def post_summary_tweet_thread(gospel_summary_lines)
    # Create a reference to the previous tweet ID for threading
    previous_tweet_id = nil

    gospel_summary_lines.each_with_index do |line, index|
      # Add a line break for the first tweet after the gospel reference
      if index == 0
        line.sub!('1/', "\\1\n\u200B\n\n1/")
      end
      # Prepare tweet_data with the line and in_reply_to_status_id (if available)
      tweet_data = {
        "text": line
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
    response = @token.post(
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

  def get_following
     endpoint_url = "https://api.twitter.com/2/users/me/following"

     query_params = {
       "max_results" => 1000,
       "user.fields" => "created_at"
     }

     options = {
       method: 'get',
       headers: {
         "User-Agent" => "TwitterService",
         "Authorization" => "Bearer #{@bearer_token}",
       },
       params: query_params
     }

     request = Typhoeus::Request.new(endpoint_url, options)
     response = request.run

     if response.code == 200
       JSON.parse(response.body)['data']
     else
       raise "Error getting following: #{JSON.parse(response.body)}"
     end
   end

  def get_followers
    endpoint_url  = 'https://api.twitter.com/2/users/me/followers'

    query_params = {
    "max_results" => 1000,
    "user.fields" => "created_at"
  }

    options = {
      method: 'get',
      headers: {
        "User-Agent" => "TwitterService",
        "Authorization" => "Bearer #{@bearer_token}",
      },
      params: query_params
    }

    request = Typhoeus::Request.new(endpoint_url, options)
    response = request.run

    if response.code == 200
      JSON.parse(response.body)['data']
    else
      raise "Error getting followers: #{JSON.parse(response.body)}"
    end
  end


  def search_users(query)
    endpoint_url = "https://api.twitter.com/2/users/by"

    query_params = {
      "usernames" => query,
      "user.fields" => "created_at,public_metrics"
    }

    options = {
      method: 'get',
      headers: {
        "User-Agent" => "TwitterService",
        "Authorization" => "Bearer #{@bearer_token}",
      },
      params: query_params
    }

    request = Typhoeus::Request.new(endpoint_url, options)
    response = request.run

    if response.code == 200
      JSON.parse(response.body)['data']
    else
      raise "Error searching users: #{JSON.parse(response.body)}"
    end
  end

  def follow_user(target_user_id)
    endpoint_url = "https://api.twitter.com/1.1/friendships/create.json"

    query_params = {
      "user_id" => target_user_id,
    }

    options = {
      method: 'post',
      headers: {
        "User-Agent" => "TwitterService",
        "Authorization" => "Bearer #{@bearer_token}",
      },
      params: query_params
    }

    request = Typhoeus::Request.new(endpoint_url, options)
    response = request.run

    if response.code == 200
      JSON.parse(response.body)
    else
      raise "Error following user: #{JSON.parse(response.body)}"
    end
  end

  def unfollow_user(target_user_id)
    endpoint_url = "https://api.twitter.com/1.1/friendships/destroy.json"

    query_params = {
      "user_id" => target_user_id,
    }

    options = {
      method: 'post',
      headers: {
        "User-Agent" => "TwitterService",
        "Authorization" => "Bearer #{@bearer_token}",
      },
      params: query_params
    }

    request = Typhoeus::Request.new(endpoint_url, options)
    response = request.run

    if response.code == 200
      JSON.parse(response.body)
    else
      raise "Error unfollowing user: #{JSON.parse(response.body)}"
    end
  end

  class << self
    def post_tweet(quote, image_data)
      new.post_tweet(quote, image_data)
    end

    def post_tweet_without_image(text)
      new.post_tweet_without_image(text)
    end

    def post_summary_tweet_thread(gospel_summary)
      new.post_summary_tweet_thread(gospel_summary)
    end

    def get_following
      new.get_following
    end

    def get_followers
      new.get_followers
    end
    # Add the class methods to the self block

    def search_users(query)
      new.search_users(query)
    end

    def follow_user(target_user_id)
      new.follow_user(target_user_id)
    end

    def unfollow_user(target_user_id)
      new.unfollow_user(target_user_id)
    end
  end

end
