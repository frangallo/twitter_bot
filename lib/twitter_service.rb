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

  def post_tweet_without_image(text, opening_line)
  text_utf8 = "#{opening_line}\n\n\u200B\n\n" + text.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')

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

  def post_summary_tweet_thread(gospel_summary_lines, first_tweet_text)
    # Create a reference to the previous tweet ID for threading
    previous_tweet_id = nil

    gospel_summary_lines.each_with_index do |line, index|
      # Add a line break for the first tweet after the gospel reference
      if index == 0
        line.gsub!(/#{Regexp.quote(first_tweet_text)}\s*(.*?)([:.])/m, "#{first_tweet_text}\n\n\u200B\n\n\\1\\2")
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

  def get_following(user_id, next_token = nil)
    url = "https://api.twitter.com/2/users/#{user_id}/following"
    params = {
      'max_results' => 1000,
      'pagination_token' => next_token
    }.compact

    query_string = URI.encode_www_form(params)
    full_url = "#{url}?#{query_string}"

    response = @token.get(full_url)
    response_body = response.body.force_encoding('UTF-8')

    if response.code == '200'
      data = JSON.parse(response_body)
      following = data['data']
      [following, data['meta']['next_token']]
    else
      raise "Error getting following list: #{JSON.parse(response_body)}"
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

  def search_users(user_id, next_token = nil)
    url = "https://api.twitter.com/2/users/#{user_id}/followers"
    params = {
      'max_results' => 1000,
      'user.fields' => 'id,username,name,description,profile_image_url,created_at,public_metrics',
      'pagination_token' => next_token
    }.compact

    query_string = URI.encode_www_form(params)
    full_url = "#{url}?#{query_string}"

    response = @token.get(full_url)
    response_body = response.body.force_encoding('UTF-8')


    if response.code == '200'
      data = JSON.parse(response_body)
      users = data['data']
      filtered_users = users.select { |user| user['description'].match?(/Jesus|Catholic|Christian|God/i) }
      [filtered_users, data['meta']['next_token']]
    else
      raise "Error searching users: #{JSON.parse(response_body)}"
    end
  end

  def follow_user(target_user_id)
    endpoint_url = "https://api.twitter.com/2/users/1256062256330223623/following"

    body = {
        "target_user_id" => target_user_id
      }.to_json

    options = {
      method: 'post',
      headers: {
        "User-Agent" => "TwitterService",
        "Authorization" => oauth_header('POST', endpoint_url),
        "Content-Type" => "application/json"
      },
      body: body
    }

    request = Typhoeus::Request.new(endpoint_url, options)
    response = request.run

    if response.code == 200
      user_data = JSON.parse(response.body)
      puts "Successfully followed user: #{user_data['data']['username']} (ID: #{user_data['data']['id']})"
      user_data
    else
      raise "Error following user: #{JSON.parse(response.body)}"
    end
  end

  def unfollow_user(target_user_id)
    endpoint_url = "https://api.twitter.com/2/users/1256062256330223623/following/#{target_user_id}"

    options = {
      method: 'delete',
      headers: {
        "User-Agent" => "TwitterService",
        "Authorization" => oauth_header('DELETE', endpoint_url),
        "Content-Type" => "application/json"
      }
    }

    request = Typhoeus::Request.new(endpoint_url, options)
    response = request.run

    if response.code == 200
      JSON.parse(response.body)
    else
      raise "Error unfollowing user: #{JSON.parse(response.body)}"
    end
  end

  def oauth_header(method, url)
    require 'signet/oauth_1/client'

    oauth_client = Signet::OAuth1::Client.new(
      client_credential_key: @consumer_key,
      client_credential_secret: @consumer_secret,
      token_credential_key: @access_token,
      token_credential_secret: @access_token_secret
    )

    oauth_client.generate_authenticated_request(
      method: method,
      uri: url
    )['Authorization']
  end

  def get_users_data(user_id)
    endpoint_url  = "https://api.twitter.com/2/users/#{user_id}"
    query_params = {
      "user.fields" => "id,username,name,description,created_at,public_metrics"
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
      raise "Error getting user data: #{JSON.parse(response.body)}"
    end
  end

  def fetch_tweets_from_users(user_ids, keywords)
    endpoint_url = 'https://api.twitter.com/2/tweets/search/recent'
    query = "from:#{user_ids.join(' from:')} (#{keywords.join(' OR ')})"
    max_results = 100
    start_time = (Time.now.utc - 10.minutes).iso8601

    options = {
      method: 'get',
      headers: {
        "User-Agent" => "TwitterStreamListener",
        "Authorization" => "Bearer #{bearer_token}"
      },
      params: {
        "query": query,
        "tweet.fields": "author_id,created_at",
        "max_results": max_results,
        "start_time": start_time
      }
    }

    request = Typhoeus::Request.new(endpoint_url, options)
    response = request.run

    if response.code == 200
      JSON.parse(response.body)['data']
    else
      raise "Error fetching tweets: #{JSON.parse(response.body)}"
    end
  end

  class << self
    def post_tweet(quote, image_data)
      new.post_tweet(quote, image_data)
    end

    def post_tweet_without_image(text, opening_line)
      new.post_tweet_without_image(text, opening_line)
    end

    def post_summary_tweet_thread(gospel_summary, first_tweet_text)
      new.post_summary_tweet_thread(gospel_summary, first_tweet_text)
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

    def get_users_data(user_id)
      new.get_users_data(user_id)
    end

    def fetch_tweets_from_users(user_ids, keywords)
      new.fetch_tweets_from_users(user_ids, keywords)
    end
  end

end
