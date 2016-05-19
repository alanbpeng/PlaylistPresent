var previewAudio = null;

var displayPlay = function(np) {
  np.removeClass("btn-default");
  np.addClass("btn-success")
  np.addClass("preview-btn-playing");
  np.children(".preview-icon").addClass("glyphicon-stop");
  np.children(".preview-icon").removeClass("glyphicon-play");
};

var displayStop = function(np) {
  np.removeClass("preview-btn-playing");
  np.removeClass("btn-success");
  np.addClass("btn-default");
  np.children(".preview-icon").removeClass("glyphicon-stop");
  np.children(".preview-icon").addClass("glyphicon-play");
};

var playAudio = function(np) {
  previewAudio = new Audio(np.attr("data-preview-url"));
  previewAudio.play();
  previewAudio.addEventListener('pause', function() {
    displayStop(np);
  });
  previewAudio.addEventListener('ended', function() {
    displayStop(np);
  });
};

$(function () {
  $('.preview-btn').click(function () {
    // Stop music if the stop button is pressed
    if ($(this).hasClass("preview-btn-playing")) {
      previewAudio.pause();
      return;
    }
    // Else, stop the currently playing track, if any
    if (previewAudio != null) {
      previewAudio.pause();
    }
    // Play the current track
    displayPlay($(this));
    playAudio($(this));
  });
});

$(window).bind('page:change', function() {
  if (previewAudio != null) {
    previewAudio.pause();
  }
});
