class CreateAlbumArtists < ActiveRecord::Migration
  def change
    create_table :album_artists do |t|
      t.integer :album_id, null: false
      t.integer :artist_id, null: false
      t.timestamps null: false
    end
    # add_index :album_artists, :artist_id
    add_index :album_artists, :album_id
  end
end
