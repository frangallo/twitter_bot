class FollowedUser < ApplicationRecord
  validates :twitter_id, uniqueness: true
end
