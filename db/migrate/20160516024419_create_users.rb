class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :user_id, null: false
      t.string :access_token
      t.datetime :expiry_date
      t.string :refresh_token
      t.string :selected_playlist_id
      t.string :url

      t.timestamps null: false
    end
    # add_index :users, :user_id, unique: true
  end
end
