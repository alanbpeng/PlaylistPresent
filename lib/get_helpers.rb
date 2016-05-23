module GetHelpers
  # Sends and (implicitly) returns the given request
  def GetHelpers.send_request(spotify_uri, spotify_req)
    Net::HTTP.start(spotify_uri.hostname, spotify_uri.port,
                    use_ssl: spotify_uri.scheme == 'https') do |http|
      http.request(spotify_req)
    end
  end

  def GetHelpers.destroy_data
    Track.destroy_all
    Artist.destroy_all
    Album.destroy_all
    TrackArtist.destroy_all
    AlbumArtist.destroy_all
  end
end