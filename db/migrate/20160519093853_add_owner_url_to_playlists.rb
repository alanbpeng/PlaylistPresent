class AddOwnerUrlToPlaylists < ActiveRecord::Migration
  def change
    add_column :playlists, :owner_url, :string
  end
end
