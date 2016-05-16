class AddEtagsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :etag_tracks, :string
    add_column :users, :etag_playlists, :string
  end
end
