class Track < ActiveRecord::Base
  require "get_helpers"

  belongs_to :album
  has_many :track_artists
  has_many :artists, :through => :track_artists

  validates :track_id, uniqueness: true

  def self.get_tracks(user)
    # Get track information
    tracks = []
    track_artists = []
    artist_ids = []
    album_ids = []
    offset = 0
    while true do
      tracks_res = nil
      if user.selected_playlist_id==""
        tracks_res = self.call_get_library_tracks(user, offset)
      else
        tracks_res = self.call_get_playlist_tracks(user, offset)
      end
      tracks_body = JSON.parse(tracks_res.body)
      if tracks_res.is_a?(Net::HTTPSuccess)
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
        raise "Error when getting tracks: #{tracks_body['error']['message']} (#{tracks_body['error']['status']})"
      end
    end

    # Get album information 20 at a time
    albums = []
    album_artists = []
    album_ids = album_ids.uniq
    while album_ids.count>0 do
      album_queries = album_ids.shift(20).join(',')
      album_res = self.call_get_albums(user, album_queries)
      albums_body = JSON.parse(album_res.body)
      if album_res.is_a?(Net::HTTPSuccess)
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
        raise "Error when getting albums: #{album_res['error']['message']} (#{album_res['error']['status']})"
      end
    end

    # Get artist information 50 at a time
    artists = []
    artist_ids = artist_ids.uniq
    artist_ids.each do |a|
      artists.push(Artist.new({artist_id: a[:artist_id],
                               name: a[:name],
                               # image_url: nil,
                               url: a[:url]}))
    end

    # Reset and save all data, as well as the associations
    GetHelpers.destroy_data

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
  end

  private

  # Makes a GET request for the tracks in the selected playlist
  def self.call_get_playlist_tracks(user, offset=0, limit=100)
    owner = Playlist.find_by(playlist_id: user.selected_playlist_id).owner

    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/users/#{owner}/playlists/#{user.selected_playlist_id}/tracks")
    spotify_uri.query = URI.encode_www_form({limit: limit, offset: offset})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.get_access_token}"

    GetHelpers.send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the tracks in the library
  def self.call_get_library_tracks(user, offset=0, limit=50)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/me/tracks")
    spotify_uri.query = URI.encode_www_form({limit: limit, offset: offset})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.get_access_token}"

    GetHelpers.send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the details of the given albums
  def self.call_get_albums(user, albums)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/albums")
    spotify_uri.query = URI.encode_www_form({ids: albums})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.get_access_token}"

    GetHelpers.send_request(spotify_uri, spotify_req)
  end
end
