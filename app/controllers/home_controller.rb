class HomeController < ApplicationController
  def index
    if User.count==0
      redirect_to admin_path and return
  	end
    @user = User.first
    @playlist_current = Playlist.find_by(playlist_id: @user.selected_playlist_id)
    @albums = Album.all.order(:name)
    @cc = ENV['cc_localhost_override'] || request.location.country_code
  end
end
