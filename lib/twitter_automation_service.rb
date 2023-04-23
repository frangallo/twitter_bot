require 'json'
require 'net/http'
require 'time'
require_relative 'twitter_service'

class TwitterAutomationService
  FOLLOW_LIMIT = 30
  UNFOLLOW_LIMIT = 30
  FOLLOW_WAIT_TIME = 1800 # 30 minutes in seconds
  UNFOLLOW_WAIT_TIME = 1800 # 30 minutes in seconds

  def initialize
    @twitter_service = TwitterService.new
  end

  def should_follow?(user, following_ids)
    has_profile_pic = user['profile_image_url'].present?
    has_keywords = user['description'].match?(/Jesus|Catholic|Christian|God/i)
    has_recent_tweet = (Time.now - Time.parse(user['created_at'])) <= 7 * 24 * 60 * 60
    has_enough_followers = user['public_metrics']['followers_count'] > 50
    not_already_following = !following_ids.include?(user['id'])

    has_profile_pic && has_keywords && has_recent_tweet && has_enough_followers && not_already_following
  end

  def follow_users
    followed_count = 0
    user_ids = [26483706, 16588111,20545055, 5577902, 27500565, 47018380, 22000517, 23721478] # List of user IDs whose followers you want to fetch
    your_user_id = 1256062256330223623;

    # Fetch the list of users you're following
    following_ids = []
    next_token = nil
    loop do
      following, next_token = @twitter_service.get_following(your_user_id, next_token)
      following_ids.concat(following.map { |user| user['id'] })
      break if next_token.nil?
    end

    user_ids.each do |user_id|
      next_token = nil

      loop do
        break if followed_count >= FOLLOW_LIMIT

        users, next_token = @twitter_service.search_users(user_id, next_token)
        users.each do |user|
          if should_follow?(user, following_ids)
            @twitter_service.follow_user(user['id'])
            followed_count += 1
            sleep FOLLOW_WAIT_TIME
          end

          break if followed_count >= FOLLOW_LIMIT
        end

        break if next_token.nil?
      end
    end
  end

  def should_unfollow?(user)
    user_data = @twitter_service.get_users_data(user['id'])
    not_following_us = !user['followed_by']
    following_duration = Time.now - Time.parse(user_data['created_at'])
    puts "User ID: #{user['id']} - Not following us: #{not_following_us} - Following duration: #{following_duration} - User data: #{user.inspect}"
    not_following_us && following_duration >= 5 * 24 * 60 * 60
  end

  def unfollow_users
    unfollowed_count = 0
    next_token = nil
    your_user_id = 1256062256330223623;

    loop do
      break if unfollowed_count >= UNFOLLOW_LIMIT

      following, next_token = @twitter_service.get_following(your_user_id, next_token)
      puts "Fetched following users: #{following.count}"

      if following.empty?
        puts "No users to process."
        break
      end

      following.each do |user|
        puts "Checking user: #{user['id']}"
        if should_unfollow?(user)
          @twitter_service.unfollow_user(user['id'])
          unfollowed_count += 1
          sleep UNFOLLOW_WAIT_TIME
        end

        break if unfollowed_count >= UNFOLLOW_LIMIT
      end

      # If there is no next_token, it means we have reached the end of the list.
      break unless next_token
    end
  end
end
