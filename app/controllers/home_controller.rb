class HomeController < ApplicationController
  def index
    # render plain: "nothing to see here"
    @albums = Album.all.order(:name)
  end
end
