class AdminController < ApplicationController
  http_basic_authenticate_with name: ENV['admin_username'], password: ENV['admin_password']

  def index
    @user = User.first
    unless @user == nil
      @playlist_current = Playlist.find_by(playlist_id: @user.selected_playlist_id)
    end
    @playlists = Playlist.all
    @albums = Album.all.order(:name)
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
        token_res = call_get_tokens({grant_type: "authorization_code",
                               code: auth_res_params["code"][0],
                               redirect_uri: session[:redirect_uri]})
        if token_res.is_a?(Net::HTTPSuccess)
          # Pass the response to the User model to add the user
          token_body = JSON.parse(token_res.body)
          
          # Use the access token to fetch the user ID
          profile_res = call_get_profile(token_body['access_token'])
          if profile_res.is_a?(Net::HTTPSuccess)
            profile_body = JSON.parse(profile_res.body)

            User.destroy_all
            User.create!(user_id: profile_body['id'],
                         access_token: token_body['access_token'],
                         expiry_date: DateTime.parse(token_res['Date'].to_s)+token_body['expires_in'].to_i.seconds, 
                         refresh_token: token_body['refresh_token'],
                         url: profile_body['external_urls']['spotify'],
                         selected_playlist_id: "")

            # redirect_to admin_path
            flash[:info] = "You have been signed in."
            redirect_to admin_refresh_playlists_path
            return
          end
          
          # Else, could not complete token request for some reason
          profile_body = JSON.parse(profile_res.body)
          flash[:danger] = "Error when getting profile info: #{profile_body['error']['message']} (#{profile_body['error']['status']})"
          redirect_to admin_path
          return
        end
        
        # Else, could not complete token request for some reason
        token_body = JSON.parse(token_res.body)
        flash[:danger] = "Error when getting tokens: #{token_body['error_description']} (#{token_body['error']})"
        redirect_to admin_path
        return
      
      elsif auth_res_params.has_key?("error")
        flash[:danger] = "Error when authenticating: returned \"#{auth_res_params["error"][0]}\""
        redirect_to admin_path
        return
      end
    end

    # If we got here, callback is improperly reached
    flash[:danger] = "Error: invalid callback"
    redirect_to admin_path
    return
  end

  def logout
    User.destroy_all
    Playlist.destroy_all
    destroy_data
    flash[:info] = "You have been signed out."
    redirect_to admin_path
  end

  def refresh_playlists
    user = User.first

    # Refresh token if it expired
    # TODO: refactor
    if (user.expiry_date <=> DateTime.current.in_time_zone('UTC'))!=1
      token_res = call_get_tokens({grant_type: "refresh_token",
                             refresh_token: user.refresh_token})
      if token_res.is_a?(Net::HTTPSuccess)
        token_body = JSON.parse(token_res.body)
        user.access_token = token_body['access_token']
        user.expiry_date = DateTime.parse(token_res['Date'].to_s)+token_body['expires_in'].to_i.seconds
        user.save
      else
        token_body = JSON.parse(token_res.body)
        flash[:danger] = "Error when refreshing token: #{token_body['error_description']} (#{token_body['error']})"
        redirect_to admin_path
        return
      end
    end

    # Populate the available playlists
    playlists = []
    offset = 0
    while true do
      playlists_res = call_get_playlists(user, offset)
      if playlists_res.is_a?(Net::HTTPSuccess)
        playlists_body = JSON.parse(playlists_res.body)
        playlists_body['items'].each do |pl|
          playlists.push(Playlist.new({playlist_id: pl['id'],
                                       name: pl['name'],
                                       owner: pl['owner']['id'],
                                       owner_url: pl['owner']['external_urls']['spotify'],
                                       url: pl['external_urls']['spotify'],
                                       public: pl['public']=="true",
                                       collaborative: pl['collaborative']=="true"}))
        end
        offset = playlists_body['limit'].to_i + playlists_body['offset']
        break unless offset < playlists_body['total'].to_i
      else
        playlists_body = JSON.parse(playlists_res.body)
        flash[:danger] = "Error when getting playlists: #{playlists_body['error']['message']} (#{playlists_body['error']['status']})"
        redirect_to admin_path
        return
      end
    end

    Playlist.destroy_all
    playlists.each do |pl|
      pl.save
    end

    if flash[:info]
      flash.keep
    else 
      flash[:info] = "The playlists have been refreshed."
    end
    redirect_to admin_path
  end

  def select_playlist
    User.first.update(selected_playlist_id: params[:user][:selected_playlist_id])
    destroy_data
    # redirect_to admin_path
    redirect_to admin_get_tracks_path
  end

  def get_tracks
    user = User.first

    # Refresh token if it expired
    # TODO: refactor
    if (user.expiry_date <=> DateTime.current.in_time_zone('UTC'))!=1
      token_res = call_get_tokens({grant_type: "refresh_token",
                                   refresh_token: user.refresh_token})
      if token_res.is_a?(Net::HTTPSuccess)
        token_body = JSON.parse(token_res.body)
        user.access_token = token_body['access_token']
        user.expiry_date = DateTime.parse(token_res['Date'].to_s)+token_body['expires_in'].to_i.seconds
        user.save
      else
        token_body = JSON.parse(token_res.body)
        flash[:danger] = "Error when refreshing token: #{token_body['error_description']} (#{token_body['error']})"
        redirect_to admin_path
        return
      end
    end
    
    # Get track information
    tracks = []
    track_artists = []
    artist_ids = []
    album_ids = []
    offset = 0
    while true do
      tracks_res = nil
      if user.selected_playlist_id==""
        tracks_res = call_get_library_tracks(user, offset)
      else
        tracks_res = call_get_playlist_tracks(user, offset)
      end
      if tracks_res.is_a?(Net::HTTPSuccess)
        tracks_body = JSON.parse(tracks_res.body)
        tracks_body['items'].each do |tt|
          t = tt['track']
          tracks.push(Track.new({track_id: t['id'],
                                 name: t['name'],
                                 album_id: t['album']['id'],
                                 disc_number: t['disc_number'].to_i,
                                 track_number: t['track_number'].to_i,
                                 explicit: t['explicit']==true,
                                 duration_ms: t['duration_ms'].to_i,
                                 url: t['external_urls']['spotify'],
                                 preview_url: t['preview_url']}))
          t['artists'].each do |a|
            track_artists.push({track_id: t['id'], artist_id: a['id']})
            artist_ids.push(a['id'])
          end
          album_ids.push(t['album']['id'])
        end
        offset = tracks_body['limit'].to_i + tracks_body['offset']
        break unless offset < tracks_body['total'].to_i
      else
        tracks_body = JSON.parse(tracks_res.body)
        flash[:danger] = "Error when getting tracks: #{tracks_body['error']['message']} (#{tracks_body['error']['status']})"
        redirect_to admin_path
        return
      end
    end

    # Get album information 20 at a time
    albums = []
    album_artists = []
    album_ids = album_ids.uniq
    while album_ids.count>0 do
      album_queries = album_ids.shift(20).join(',')
      album_res = call_get_albums(user, album_queries)
      if album_res.is_a?(Net::HTTPSuccess)
        albums_body = JSON.parse(album_res.body)
        albums_body['albums'].each do |a|
          albums.push(Album.new({album_id: a['id'],
                                 name: a['name'],
                                 year: a['release_date'][0..3],
                                 image_url: (a['images'].empty? ? nil : a['images'][0]['url']),
                                 url: a['external_urls']['spotify']}))
          a['artists'].each do |ar|
            album_artists.push({album_id: a['id'], artist_id: ar['id']})
            artist_ids.push(ar['id'])
          end
        end
      else
        album_res = JSON.parse(album_res.body)
        flash[:danger] = "Error when getting albums: #{album_res['error']['message']} (#{album_res['error']['status']})"
        redirect_to admin_path
        return
      end
    end

    # Get artist information 50 at a time
    artists = []
    artist_ids = artist_ids.uniq
    while artist_ids.count>0 do
      artist_queries = artist_ids.shift(50).join(',')
      artist_res = call_get_artists(user, artist_queries)
      if artist_res.is_a?(Net::HTTPSuccess)
        artist_body = JSON.parse(artist_res.body)
        artist_body['artists'].each do |a|
          artists.push(Artist.new({artist_id: a['id'],
                                   name: a['name'],
                                   image_url: a['images'][0],
                                   url: a['external_urls']['spotify']}))
        end
      else
        artist_res = JSON.parse(artist_res.body)
        flash[:danger] = "Error when getting artists: #{artist_res['error']['message']} (#{artist_res['error']['status']})"
        redirect_to admin_path
        return
      end
    end

    # Reset and save all data, as well as the associations
    destroy_data

    albums.each do |a|
      a.save
    end
    tracks.each do |t|
      t.album = Album.find_by(album_id: t.album_id)
      t.save
    end
    artists.each do |a|
      a.save
    end
    track_artists.each do |ta|
      Artist.find_by(artist_id: ta[:artist_id]).tracks << Track.find_by(track_id: ta[:track_id])
    end
    album_artists.each do |aa|
      Artist.find_by(artist_id: aa[:artist_id]).albums << Album.find_by(album_id: aa[:album_id])
    end

    flash[:info] = "Successfully populated the tracks."
    if params[:quick]
      redirect_to root_path
    else
      redirect_to admin_path
    end
  end

  private

  # Makes a POST request for the access and refresh tokens
  def call_get_tokens(params)
    # Set up the request
    spotify_uri = URI("https://accounts.spotify.com/api/token")
    spotify_req = Net::HTTP::Post.new(spotify_uri)
    spotify_req['Authorization'] = "Basic #{Base64.strict_encode64(ENV['spotify_client_id']+':'+ENV['spotify_client_secret'])}"
    spotify_req.set_form_data(params)

    send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the basic profile info for the user
  def call_get_profile(access_token)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/me")
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{access_token}"

    send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the user's playlists
  def call_get_playlists(user, offset=0, limit=50)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/me/playlists")
    spotify_uri.query = URI.encode_www_form({limit: limit, offset: offset})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.access_token}"

    send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the tracks in the selected playlist
  def call_get_playlist_tracks(user, offset=0, limit=100)
    owner = Playlist.find_by(playlist_id: user.selected_playlist_id).owner
    fields = "items(track(album(external_urls(spotify),id,images,name),artists(external_urls(spotify),id,name),disc_number,duration_ms,explicit,external_urls(spotify),id,name,preview_url,track_number)),limit,offset,total"

    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/users/#{owner}/playlists/#{user.selected_playlist_id}/tracks")
    spotify_uri.query = URI.encode_www_form({fields: fields, limit: limit, offset: offset})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.access_token}"

    send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the tracks in the library
  def call_get_library_tracks(user, offset=0, limit=50)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/me/tracks")
    spotify_uri.query = URI.encode_www_form({limit: limit, offset: offset})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.access_token}"

    send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the details of the given albums
  def call_get_albums(user, albums)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/albums")
    spotify_uri.query = URI.encode_www_form({ids: albums})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.access_token}"

    send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the details of the given artists
  def call_get_artists(user, artists)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/artists")
    spotify_uri.query = URI.encode_www_form({ids: artists})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.access_token}"

    send_request(spotify_uri, spotify_req)
  end

  # Sends and (implicitly) returns the given request
  def send_request(spotify_uri, spotify_req)
    Net::HTTP.start(spotify_uri.hostname, spotify_uri.port,
                    use_ssl: spotify_uri.scheme == 'https') do |http|
      http.request(spotify_req)
    end
  end

  def destroy_data
    Track.destroy_all
    Artist.destroy_all
    Album.destroy_all
    TrackArtist.destroy_all
    AlbumArtist.destroy_all
  end

end
