class CreateAlbums < ActiveRecord::Migration
  def change
    create_table :albums do |t|
      t.string :album_id, null: false
      t.string :name
      # t.string :artist_id
      t.string :image_url
      t.string :year
      t.string :url

      t.timestamps null: false
    end
    add_index :albums, :album_id, unique: true
  end
end
