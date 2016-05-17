class Album < ActiveRecord::Base
  validates :album_id, uniqueness: true
end
