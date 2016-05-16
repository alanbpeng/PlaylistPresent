class Playlist < ActiveRecord::Base
  validates :playlist_id, uniqueness: true
  # self.primary_key = :playlist_id
end
