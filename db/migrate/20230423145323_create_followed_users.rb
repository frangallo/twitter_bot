class CreateFollowedUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :followed_users do |t|
      t.string :twitter_id, null: false

      t.timestamps
    end
    add_index :followed_users, :twitter_id, unique: true
  end
end
