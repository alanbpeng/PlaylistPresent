class AdminController < ApplicationController
  require "send_request"

  http_basic_authenticate_with name: ENV['admin_username'], password: ENV['admin_password'], except: [:index]

  def index
    @user = User.first
    unless @user == nil
      @playlist_current = Playlist.find_by(playlist_id: @user.selected_playlist_id)
    end
    @playlists = Playlist.all
    @albums = Album.all.order(:name)
    @cc = ENV['cc_localhost_override'] || request.location.country_code
  end

  def auth
    # Determines whether to display the authorization dialogue box
    # even when previously authorized
    show_dialog = true
    # Setup the state and redirect_uri parameters
    flash[:redirect_uri] = "#{request.original_url}/callback"
    flash[:state] = SecureRandom.hex()
    
    # redirect to Spotify page for authorization
    redirect_to "https://accounts.spotify.com/authorize/?client_id=#{ENV['spotify_client_id']}&response_type=code&redirect_uri=#{flash[:redirect_uri]}&scope=playlist-read-private%20playlist-read-collaborative%20user-library-read&state=#{flash[:state]}&show_dialog=#{show_dialog.to_s}"
  end

  def callback
    begin
      # Parse the returned parameters
      auth_res_params = CGI.parse(request.query_string)
      # Checks if the state parameter is consistent
      if auth_res_params.has_key?("state") && auth_res_params["state"][0] == flash[:state]
        # Check for either code or error parameter
        if auth_res_params.has_key?("code")
          User.create_user(auth_res_params["code"][0], flash[:redirect_uri])
        elsif auth_res_params.has_key?("error")
          raise "Error when authenticating: returned \"#{auth_res_params["error"][0]}\""
        end
      else
        # If we got here, callback is improperly reached
        raise "Error: invalid callback"
      end
    rescue RuntimeError => err
      flash[:danger] = err
      redirect_to admin_path
      return
    end
    
    # Proceed to next step when done
    destroy_data
    flash[:info] = "You have been signed in."
    redirect_to admin_refresh_playlists_path
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
    begin
      # Populate the available playlists
      Playlist.populate_playlists
    rescue RuntimeError => err
      flash[:danger] = err
      redirect_to admin_path
      return
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
    redirect_to admin_get_tracks_path
  end

  def get_tracks
    user = User.first

    begin
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
                                   available_markets: t['available_markets'],
                                   url: t['external_urls']['spotify'],
                                   preview_url: t['preview_url']}))
            t['artists'].each do |a|
              track_artists.push({track_id: t['id'], artist_id: a['id']})
              artist_ids.push({artist_id: a['id'], name: a['name'], url: a['external_urls']['spotify']})
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
                                   url: a['external_urls']['spotify'],
                                   available_markets: a['available_markets']}))
            a['artists'].each do |ar|
              album_artists.push({album_id: a['id'], artist_id: ar['id']})
              artist_ids.push({artist_id: ar['id'], name: ar['name'], url: ar['external_urls']['spotify']})
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
      # while artist_ids.count>0 do
      #   artist_queries = artist_ids.shift(50).join(',')
      #   artist_res = call_get_artists(user, artist_queries)
      #   if artist_res.is_a?(Net::HTTPSuccess)
      #     artist_body = JSON.parse(artist_res.body)
      #     artist_body['artists'].each do |a|
      #       artists.push(Artist.new({artist_id: a['id'],
      #                                name: a['name'],
      #                                image_url: a['images'][0],
      #                                url: a['external_urls']['spotify']}))
      #     end
      #   else
      #     artist_res = JSON.parse(artist_res.body)
      #     flash[:danger] = "Error when getting artists: #{artist_res['error']['message']} (#{artist_res['error']['status']})"
      #     redirect_to admin_path
      #     return
      #   end
      # end
      artist_ids.each do |a|
        artists.push(Artist.new({artist_id: a[:artist_id],
                                 name: a[:name],
                                 # image_url: nil,
                                 url: a[:url]}))
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

    rescue RuntimeError => err
      flash[:danger] = err
      redirect_to admin_path
      return
    end

    flash[:info] = "Successfully populated the tracks."
    if params[:quick]
      redirect_to root_path
    else
      redirect_to admin_path
    end
  end

  private

  # Makes a GET request for the tracks in the selected playlist
  def call_get_playlist_tracks(user, offset=0, limit=100)
    owner = Playlist.find_by(playlist_id: user.selected_playlist_id).owner
    # fields = "items(track(album(external_urls(spotify),id,images,name),artists(external_urls(spotify),id,name),disc_number,duration_ms,explicit,external_urls(spotify),id,name,preview_url,track_number)),limit,offset,total"

    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/users/#{owner}/playlists/#{user.selected_playlist_id}/tracks")
    spotify_uri.query = URI.encode_www_form({limit: limit, offset: offset})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.get_access_token}"

    SendRequest.send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the tracks in the library
  def call_get_library_tracks(user, offset=0, limit=50)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/me/tracks")
    spotify_uri.query = URI.encode_www_form({limit: limit, offset: offset})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.get_access_token}"

    SendRequest.send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the details of the given albums
  def call_get_albums(user, albums)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/albums")
    spotify_uri.query = URI.encode_www_form({ids: albums})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.get_access_token}"

    SendRequest.send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the details of the given artists
  def call_get_artists(user, artists)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/artists")
    spotify_uri.query = URI.encode_www_form({ids: artists})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.get_access_token}"

    SendRequest.send_request(spotify_uri, spotify_req)
  end

  def destroy_data
    Track.destroy_all
    Artist.destroy_all
    Album.destroy_all
    TrackArtist.destroy_all
    AlbumArtist.destroy_all
  end

end
