class CreateAlbumArtists < ActiveRecord::Migration
  def change
    create_table :album_artists do |t|
      t.integer :album_id, null: false
      t.integer :artist_id, null: false
      t.timestamps null: false
    end
  end
end
