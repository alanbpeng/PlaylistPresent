class AdminController < ApplicationController
  require 'get_helpers'

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
    GetHelpers.destroy_data
    flash[:info] = "You have been signed in."
    redirect_to admin_get_playlists_path
    return
  end

  def logout
    User.destroy_all
    Playlist.destroy_all
    GetHelpers.destroy_data
    flash[:info] = "You have been signed out."
    redirect_to admin_path
  end

  def get_playlists
    begin
      # Populate the available playlists
      Playlist.get_playlists(User.first)
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
    GetHelpers.destroy_data
    redirect_to admin_get_tracks_path
  end

  def get_tracks
    begin
      Track.get_tracks(User.first)
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


end
