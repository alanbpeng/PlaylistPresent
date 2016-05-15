class AdminController < ApplicationController

  def index
  end

  def auth
    show_dialog = false

    session[:redirect_uri] = "#{request.original_url}/callback"
    session[:state] = Random::DEFAULT.rand(10000000...100000000).to_s
    redirect_to "https://accounts.spotify.com/authorize/?client_id=#{ENV['spotify_client_id']}&response_type=code&redirect_uri=#{session[:redirect_uri]}&scope=playlist-read-private%20playlist-read-collaborative%20user-library-read&state=#{session[:state]}&show_dialog=#{show_dialog.to_s}"
  end

  def callback
    require 'cgi'
    res_params = CGI.parse(request.query_string)
    if res_params.has_key?("state") && res_params["state"][0] == session[:state]
      if res_params.has_key?("code")
        # TODO: do something with the code
        render plain: res_params["code"][0]
        return
      elsif res_params.has_key?("error")
        # TODO
        render plain: res_params["error"][0]
        return
      end
    end
    # TODO
    render plain: "Error: invalid callback"
  end

  private

end
