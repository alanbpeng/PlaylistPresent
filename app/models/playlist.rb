class Playlist < ActiveRecord::Base
  require "send_request"

  validates :playlist_id, uniqueness: true
  # self.primary_key = :playlist_id

  # Populate the available playlists
  def self.populate_playlists
    playlists = []
    offset = 0
    while true do
      playlists_res = self.call_get_playlists(User.first, offset)
      playlists_body = JSON.parse(playlists_res.body)
      if playlists_res.is_a?(Net::HTTPSuccess)
        playlists_body['items'].each do |pl|
          playlists.push(self.new({playlist_id: pl['id'],
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
        raise = "Error when getting playlists: #{playlists_body['error']['message']} (#{playlists_body['error']['status']})"
      end
    end
    self.destroy_all
    playlists.each do |pl|
      pl.save
    end
  end

  private

  # Makes a GET request for the user's playlists
  def self.call_get_playlists(user, offset=0, limit=50)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/me/playlists")
    spotify_uri.query = URI.encode_www_form({limit: limit, offset: offset})
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{user.get_access_token}"

    SendRequest.send_request(spotify_uri, spotify_req)
  end

end
