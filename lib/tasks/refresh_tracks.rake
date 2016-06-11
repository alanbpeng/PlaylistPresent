desc "Refresh the tracks in the currently selected playlist/library"
task refresh_tracks: :environment do
  Track.get_tracks(User.first)
  puts "Successfully populated the tracks."
end
