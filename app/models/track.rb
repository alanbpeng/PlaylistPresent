class Track < ActiveRecord::Base
  belongs_to :album
  has_many :track_artists
  has_many :artists, :through => :track_artists

  validates :track_id, uniqueness: true
end
