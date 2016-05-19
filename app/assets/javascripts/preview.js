var nowPlaying = null;
var previewAudio = null;

var displayPlay = function(nowPlaying) {
  nowPlaying.removeClass("btn-default");
  nowPlaying.addClass("btn-success")
  nowPlaying.addClass("preview-btn-playing");
  nowPlaying.children(".preview-icon").addClass("glyphicon-stop");
  nowPlaying.children(".preview-icon").removeClass("glyphicon-play");
}

var displayStop = function(nowPlaying) {
  nowPlaying.removeClass("preview-btn-playing");
  nowPlaying.removeClass("btn-success");
  nowPlaying.addClass("btn-default");
  nowPlaying.children(".preview-icon").removeClass("glyphicon-stop");
  nowPlaying.children(".preview-icon").addClass("glyphicon-play");
}

var playAudio = function(url) {
  previewAudio = new Audio(url);
  previewAudio.play();
  previewAudio.addEventListener('ended', function() {
    displayStop(nowPlaying);
  });
  previewAudio.addEventListener('pause', function() {
    displayStop(nowPlaying);
  });
}

$(function () {
  $('.preview-btn').click(function (event) {
    event.preventDefault();

    // Stop music if the stop button is pressed
    if ($(this).hasClass("preview-btn-playing")) {
      previewAudio.pause();
      displayStop(nowPlaying);
      nowPlaying = null;
      return;
    }

    // Else, stop the currently playing track, if any
    if (nowPlaying) {
      previewAudio.pause();
      displayStop(nowPlaying);
      nowPlaying = null;
    }

    // Play the current track
    nowPlaying = $(this);
    displayPlay(nowPlaying);
    playAudio(nowPlaying.attr("data-preview-url"));
    // return false;
  })
});
