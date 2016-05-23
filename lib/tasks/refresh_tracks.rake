desc "Refresh the tracks in the currently selected playlist/library"
task refresh_tracks: :environment do
  begin
    Track.get_tracks(User.first)
    puts "Successfully populated the tracks."
  rescue RuntimeError => err
    puts err
  end
end
