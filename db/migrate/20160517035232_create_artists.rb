class CreateArtists < ActiveRecord::Migration
  def change
    create_table :artists do |t|
      t.string :artist_id, null: false
      t.string :name
      t.string :image_url
      t.string :url

      t.timestamps null: false
    end
  end
end
