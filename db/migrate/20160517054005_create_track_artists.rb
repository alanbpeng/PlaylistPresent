class CreateTrackArtists < ActiveRecord::Migration
  def change
    create_table :track_artists do |t|
      t.integer :track_id, null: false
      t.integer :artist_id, null: false
      t.timestamps null: false
    end
  end
end
