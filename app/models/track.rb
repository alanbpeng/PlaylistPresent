class Track < ActiveRecord::Base
  validates :track_id, uniqueness: true
end
