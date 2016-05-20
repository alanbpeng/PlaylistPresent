class CreateTracks < ActiveRecord::Migration
  def change
    create_table :tracks do |t|
      t.string :track_id, null: false
      t.string :name
      # t.string :artist_id
      t.string :album_id
      t.integer :disc_number
      t.integer :track_number
      t.boolean :explicit
      t.integer :duration_ms
      t.string :available_markets
      t.string :url
      t.string :preview_url

      t.timestamps null: false
    end
    add_index :tracks, :track_id, unique: true
  end
end
