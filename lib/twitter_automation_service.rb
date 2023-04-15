require 'json'
require 'net/http'
require 'time'
require_relative 'twitter_service'

class TwitterAutomationService
  FOLLOW_LIMIT = 125
  UNFOLLOW_LIMIT = 125
  FOLLOW_WAIT_TIME = 300 # 5 minutes in seconds
  UNFOLLOW_WAIT_TIME = 300 # 5 minutes in seconds

  def initialize
    @twitter_service = TwitterService.new
  end

  def should_follow?(user)
    has_profile_pic = user['profile_image_url'].present?
    has_keywords = user['description'].match?(/Jesus|Catholic|Christian|God/i)
    has_recent_tweet = (Time.now - Time.parse(user['created_at'])) <= 7 * 24 * 60 * 60
    has_enough_followers = user['public_metrics']['followers_count'] > 50

    has_profile_pic && has_keywords && has_recent_tweet && has_enough_followers
  end

  def follow_users
    followed_count = 0

    loop do
      break if followed_count >= FOLLOW_LIMIT

      users = @twitter_service.search_users('Jesus OR Catholic OR Christian OR God')
      users.each do |user|
        if should_follow?(user)
          @twitter_service.follow_user(user['id'])
          followed_count += 1
          sleep FOLLOW_WAIT_TIME
        end

        break if followed_count >= FOLLOW_LIMIT
      end
    end
  end

  def should_unfollow?(relationship)
    not_following_us = !relationship['source']['followed_by_target']
    following_duration = Time.now - Time.parse(relationship['source']['followed_at'])

    not_following_us && following_duration >= 5 * 24 * 60 * 60
  end

  def unfollow_users
    unfollowed_count = 0

    loop do
      break if unfollowed_count >= UNFOLLOW_LIMIT

      following = @twitter_service.get_following
      puts 'made it here....'
      following.each do |relationship|
        if should_unfollow?(relationship)
          @twitter_service.unfollow_user(relationship['target']['id'])
          unfollowed_count += 1
          sleep UNFOLLOW_WAIT_TIME
        end

        break if unfollowed_count >= UNFOLLOW_LIMIT
      end
    end
  end
end
