class CreatePlaylists < ActiveRecord::Migration
  def change
    create_table :playlists do |t|
      t.string :playlist_id, null: false
      t.string :name
      t.string :owner
      t.string :url
      t.boolean :public
      t.boolean :collaborative

      t.timestamps null: false
    end
    add_index :playlists, :playlist_id, unique: true
  end
end
