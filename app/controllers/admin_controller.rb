class AdminController < ApplicationController

  def index
    @user = User.first
    @playlists = nil

    unless @user == nil
      # Refresh token if it expired
      if (@user.expiry_date <=> DateTime.current.in_time_zone('UTC'))!=1
        token_res = get_tokens({grant_type: "refresh_token",
                               refresh_token: @user.refresh_token})
        if token_res.is_a?(Net::HTTPSuccess)
          token_body = JSON.parse(token_res.body)
          @user.access_token = token_body['access_token']
          @user.expiry_date = DateTime.parse(token_res['Date'].to_s)+token_body['expires_in'].to_i.seconds
          @user.save
        else
          token_body = JSON.parse(token_res.body)
          flash[:error] = "Error when refreshing token: #{token_body['error_description']} (#{token_body['error']})"
          return
        end
      end

      # Populate the available playlists (immediately)
      playlists_res = get_playlists(@user.access_token, @user.etag_playlists)
      if playlists_res.is_a?(Net::HTTPSuccess)
        @user.update(etag_playlists: playlists_res['Etag'])
        playlists_body = JSON.parse(playlists_res.body)
        Playlist.destroy_all
        for pl in playlists_body['items']
          Playlist.create({playlist_id: pl['id'],
                           name: pl['name'],
                           owner: pl['owner']['id'],
                           url: pl['external_urls']['spotify'],
                           public: pl['public']=="true",
                           collaborative: pl['collaborative']=="true"})
          # TODO: pagination
        end
      elsif !playlists_res.is_a?(Net::HTTPNotModified)
        profile_body = JSON.parse(profile_res.body)
        flash[:error] = "Error when getting playlists: #{profile_body['message']} (#{profile_body['status']})"
        return
      end

      @playlists = Playlist.all
    end
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
    # Parse the returned parameters
    auth_res_params = CGI.parse(request.query_string)
    # Checks if the state parameter is consistent
    if auth_res_params.has_key?("state") && auth_res_params["state"][0] == session[:state]
      # Check for either code or error parameter
      if auth_res_params.has_key?("code")
        # Makes a POST request for the access and refresh tokens
        token_res = get_tokens({grant_type: "authorization_code",
                               code: auth_res_params["code"][0],
                               redirect_uri: session[:redirect_uri]})
        if token_res.is_a?(Net::HTTPSuccess)
          # Pass the response to the User model to add the user
          token_body = JSON.parse(token_res.body)
          
          # Use the access token to fetch the user ID
          profile_res = get_profile(token_body['access_token'])
          if profile_res.is_a?(Net::HTTPSuccess)
            profile_body = JSON.parse(profile_res.body)

            User.destroy_all
            User.create!(user_id: profile_body['id'],
                         access_token: token_body['access_token'],
                         expiry_date: DateTime.parse(token_res['Date'].to_s)+token_body['expires_in'].to_i.seconds, 
                         refresh_token: token_body['refresh_token'],
                         url: profile_body['external_urls']['spotify'])

            redirect_to admin_path
            return
          end
          
          # Else, could not complete token request for some reason
          profile_body = JSON.parse(profile_res.body)
          flash[:error] = "Error when getting profile info: #{profile_body['message']} (#{profile_body['status']})"
          redirect_to admin_path
          return
        end
        
        # Else, could not complete token request for some reason
        token_body = JSON.parse(token_res.body)
        flash[:error] = "Error when getting tokens: #{token_body['error_description']} (#{token_body['error']})"
        redirect_to admin_path
        return
      
      elsif auth_res_params.has_key?("error")
        flash[:error] = "Error when authenticating: returned \"#{auth_res_params["error"][0]}\""
        redirect_to admin_path
        return
      end
    end

    # If we got here, callback is improperly reached
    flash[:error] = "Error: invalid callback"
    redirect_to admin_path
    return
  end

  def logout
    User.destroy_all
    Playlist.destroy_all
    # TODO: everything else
    redirect_to admin_path
  end


  private

  # Makes a POST request for the access and refresh tokens
  def get_tokens(params)
    # Set up the request
    spotify_uri = URI("https://accounts.spotify.com/api/token")
    spotify_req = Net::HTTP::Post.new(spotify_uri)
    spotify_req['Authorization'] = "Basic #{Base64.strict_encode64(ENV['spotify_client_id']+':'+ENV['spotify_client_secret'])}"
    spotify_req.set_form_data(params)

    # Sends and (implicitly) returns the request
    Net::HTTP.start(spotify_uri.hostname, spotify_uri.port,
                    use_ssl: spotify_uri.scheme == 'https') do |http|
      http.request(spotify_req)
    end
  end

  # Makes a GET request for the basic profile info for the user
  def get_profile(access_token)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/me")
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{access_token}"

    # Sends and (implicitly) returns the request
    Net::HTTP.start(spotify_uri.hostname, spotify_uri.port,
                    use_ssl: spotify_uri.scheme == 'https') do |http|
      http.request(spotify_req)
    end
  end

  # Makes a GET request for the user's playlists
  def get_playlists(access_token, etag=nil, limit=20, offset=0)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/me/playlists")
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{access_token}"
    spotify_req['If-None-Match'] = etag unless etag==nil
    spotify_req.set_form_data({limit: limit, offset: offset})

    # Sends and (implicitly) returns the request
    Net::HTTP.start(spotify_uri.hostname, spotify_uri.port,
                    use_ssl: spotify_uri.scheme == 'https') do |http|
      http.request(spotify_req)
    end
  end

end
