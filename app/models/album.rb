class Album < ActiveRecord::Base
  has_many :tracks
  has_many :album_artists
  has_many :artists, :through => :album_artists

  validates :album_id, uniqueness: true
end
