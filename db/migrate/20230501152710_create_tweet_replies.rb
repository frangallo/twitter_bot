class CreateTweetReplies < ActiveRecord::Migration[7.0]
  def change
    create_table :tweet_replies do |t|
      t.bigint :tweet_id, null: false

      t.timestamps
    end

    add_index :tweet_replies, :tweet_id, unique: true
  end
end
