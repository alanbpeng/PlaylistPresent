module SendRequest
  # Sends and (implicitly) returns the given request
  def SendRequest.send_request(spotify_uri, spotify_req)
    Net::HTTP.start(spotify_uri.hostname, spotify_uri.port,
                    use_ssl: spotify_uri.scheme == 'https') do |http|
      http.request(spotify_req)
    end
  end
end