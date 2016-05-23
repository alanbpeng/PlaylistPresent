class User < ActiveRecord::Base
  require "get_helpers"

  validates :user_id, uniqueness: true

  def self.create_user(code, redirect_uri)
    token_res = self.call_get_tokens({grant_type: "authorization_code",
                                      code: code,
                                      redirect_uri: redirect_uri})
    token_body = JSON.parse(token_res.body)
    if token_res.is_a?(Net::HTTPSuccess)
      # Pass the response to the User model to add the user
      # Use the access token to fetch the user ID
      profile_res = call_get_profile(token_body['access_token'])
      profile_body = JSON.parse(profile_res.body)
      if profile_res.is_a?(Net::HTTPSuccess)
        self.destroy_all
        self.create!(user_id: profile_body['id'],
                     access_token: token_body['access_token'],
                     expiry_date: DateTime.parse(token_res['Date'].to_s)+token_body['expires_in'].to_i.seconds, 
                     refresh_token: token_body['refresh_token'],
                     url: profile_body['external_urls']['spotify'],
                     selected_playlist_id: "")
        # return when done
        return
      else
        # Else, could not complete token request for some reason
        raise "Error when getting profile info: #{profile_body['error']['message']} (#{profile_body['error']['status']})"
      end
    else
      # Else, could not complete token request for some reason
      raise "Error when getting tokens: #{token_body['error_description']} (#{token_body['error']})"
    end
  end

  def get_access_token
    # Refresh token if it expired
    if (self.expiry_date <=> DateTime.current.in_time_zone('UTC'))!=1
      token_res = self.class.call_get_tokens({grant_type: "refresh_token", refresh_token: self.refresh_token})
      token_body = JSON.parse(token_res.body)
      if token_res.is_a?(Net::HTTPSuccess)
        self.access_token = token_body['access_token']
        self.expiry_date = DateTime.parse(token_res['Date'].to_s)+token_body['expires_in'].to_i.seconds
        self.refresh_token = token_body['refresh_token'] unless token_body['refresh_token']==nil
        self.save
      else
        raise "Error when refreshing token: #{token_body['error_description']} (#{token_body['error']})"
      end
    end
    return self.access_token
  end

  private

  # Makes a POST request for the access and refresh tokens
  def self.call_get_tokens(params)
    spotify_uri = URI("https://accounts.spotify.com/api/token")
    spotify_req = Net::HTTP::Post.new(spotify_uri)
    spotify_req['Authorization'] = "Basic #{Base64.strict_encode64(ENV['spotify_client_id']+':'+ENV['spotify_client_secret'])}"
    spotify_req.set_form_data(params)

    GetHelpers.send_request(spotify_uri, spotify_req)
  end

  # Makes a GET request for the basic profile info for the user
  def self.call_get_profile(access_token)
    # Set up the request
    spotify_uri = URI("https://api.spotify.com/v1/me")
    spotify_req = Net::HTTP::Get.new(spotify_uri)
    spotify_req['Authorization'] = "Bearer #{access_token}"

    GetHelpers.send_request(spotify_uri, spotify_req)
  end

end
