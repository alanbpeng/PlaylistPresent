class User < ActiveRecord::Base
  validates :user_id, uniqueness: true
  # self.primary_key = :user_id
end
