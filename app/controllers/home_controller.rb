class HomeController < ApplicationController
  def index
    if User.count==0
      redirect_to admin_path
  	end
    @albums = Album.all.order(:name)
  end
end
