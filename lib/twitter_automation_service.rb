require 'json'
require 'net/http'
require 'time'
require_relative 'twitter_service'

class TwitterAutomationService
    TARGET_USER_IDS = [1616902805402394628, 331498740,14931614, 21632108,
    5577902, 12197852, 20545055, 16588111, 27500565, 47018380, 26483706,
    22000517, 23721478, 403443988, 27379684, 36117822, 32150862, 4276531,
    71715193, 32988140, 52150569, 20985527, 156012476, 33429434, 232252457,
    34296240, 15809249, 1110475561, 111734160, 40332459, 20474254, 20124712,
    109081861, 69358916, 1467903721673744392, 144078841, 27768807, 250781699, 110743000]

  def initialize
    @twitter_service = TwitterService.new
  end

  def should_follow?(user)
    has_profile_pic = user['profile_image_url'].present?
    has_keywords = user['description'].match?(/Jesus|Catholic|Lord|Amen|Christ|Christian|God/i)
    has_recent_tweet = (Time.now - Time.parse(user['created_at'])) <= 7 * 24 * 60 * 60
    has_enough_followers = user['public_metrics']['followers_count'] > 50

    # Check if we're already following the user
    not_already_followed = !FollowedUser.exists?(twitter_id: user['id'])

    has_profile_pic && has_keywords && has_recent_tweet && has_enough_followers && not_already_followed
  end

  def follow_users
    user_ids = [26483706, 403443988, 16588111, 20545055, 5577902, 27500565, 47018380, 22000517, 23721478] # List of user IDs whose followers you want to fetch
    your_user_id = 1256062256330223623;
    random_user_id = user_ids.sample;
    next_token = nil;

    puts "Searching for followers of user ID #{random_user_id}"

    loop do
      users, next_token = @twitter_service.search_users(random_user_id, next_token)

      puts "Fetched #{users.count} users"

      users.each do |user|
        if should_follow?(user)
          # Check if the user is already followed
          followed_user = FollowedUser.find_by(twitter_id: user['id'])
          if followed_user.nil?
            puts "Following user #{user['id']}"
            # Add the user to the database
            FollowedUser.create(twitter_id: user['id'])
            @twitter_service.follow_user(user['id'])
            followed_count += 1
            return
          end
        end
      end
      break if next_token.nil?
    end

    puts "Followed #{followed_count} users"
  end



  def should_unfollow?(user)
    user_data = @twitter_service.get_users_data(user['id'])
    not_priority_account = !TARGET_USER_IDS.include?(user['id'].to_i)
    following_duration = Time.now - Time.parse(user_data['created_at'])
    puts "User ID: #{user['id']} - Following duration: #{following_duration} - User data: #{user.inspect}"
    not_priority_account && (following_duration >= 5 * 24 * 60 * 60)
  end

  def unfollow_users
    next_token = nil
    your_user_id = 1256062256330223623;

    loop do
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
          return # exit the loop after unfollowing the first user
        end
      end

      # If there is no next_token, it means we have reached the end of the list.
      break unless next_token
    end
  end

end
