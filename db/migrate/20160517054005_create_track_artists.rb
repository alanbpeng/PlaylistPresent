class CreateTrackArtists < ActiveRecord::Migration
  def change
    create_table :track_artists do |t|
      t.integer :track_id, null: false
      t.integer :artist_id, null: false
      t.timestamps null: false
    end
    add_index :track_artists, :artist_id
    add_index :track_artists, :track_id
  end
end
