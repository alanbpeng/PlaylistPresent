class AdminController < ApplicationController

  def index
    # TODO
  end

  def auth
    # Determines whether to display the authorization dialogue box
    # even when previously authorized
    show_dialog = false

    # Setup the state and redirect_uri parameters
    session[:redirect_uri] = "#{request.original_url}/callback"
    session[:state] = Random::DEFAULT.rand(10000000...100000000).to_s

    # redirect to Spotify page for authorization
    redirect_to "https://accounts.spotify.com/authorize/?client_id=#{ENV['spotify_client_id']}&response_type=code&redirect_uri=#{session[:redirect_uri]}&scope=playlist-read-private%20playlist-read-collaborative%20user-library-read&state=#{session[:state]}&show_dialog=#{show_dialog.to_s}"
  end

  def callback
    require 'cgi'

    # Parse the returned parameters
    auth_res_params = CGI.parse(request.query_string)
    # Checks if the state parameter is consistent
    if auth_res_params.has_key?("state") && auth_res_params["state"][0] == session[:state]
      # Check for either code or error parameter
      if auth_res_params.has_key?("code")
        # Makes a POST request for the access and refresh tokens
        token_res = get_tokens(auth_res_params["code"][0])

        # TODO: do something with the tokens... or error
        render plain: token_res.body
        return
      elsif auth_res_params.has_key?("error")
        # An error is returned
        flash[:error] = "Error: returned \"#{auth_res_params["error"][0]}\""
        # TODO: find a way to display the error
        render plain: flash[:error]
        return
      end
    end

    # If we got here, callback is improperly reached
    flash[:error] = "Error: invalid callback"
    # TODO: find a way to display the error
    render plain: flash[:error]
  end

  private

  # Makes a POST request for the access and refresh tokens
  def get_tokens(auth_code)
    require 'base64'
    require 'net/http'
    require 'uri'

    # Set up the request
    spotify_uri = URI("https://accounts.spotify.com/api/token")
    spotify_req = Net::HTTP::Post.new(spotify_uri)
    spotify_req['Authorization'] = "Basic #{Base64.strict_encode64(ENV['spotify_client_id']+':'+ENV['spotify_client_secret'])}"
    spotify_req.set_form_data({grant_type: "authorization_code",
                               code: auth_code,
                               redirect_uri: session[:redirect_uri]})

    # Sends and (implicitly) returns the request
    Net::HTTP.start(spotify_uri.hostname, spotify_uri.port,
                    use_ssl: spotify_uri.scheme == 'https') do |http|
      http.request(spotify_req)
    end
  end

end
