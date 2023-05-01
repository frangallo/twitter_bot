class TweetReply < ActiveRecord::Base
  validates :tweet_id, presence: true, uniqueness: true
end
