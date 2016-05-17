class Artist < ActiveRecord::Base
  has_many :track_artists
  has_many :album_artists
  has_many :tracks, :through => :track_artists
  has_many :albums, :through => :album_artists
  
  validates :artist_id, uniqueness: true
end
