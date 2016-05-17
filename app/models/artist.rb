class Artist < ActiveRecord::Base
  validates :artist_id, uniqueness: true
end
