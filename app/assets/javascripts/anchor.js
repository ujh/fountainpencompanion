document.addEventListener("DOMContentLoaded", function () {
  if (location.hash) {
    var element = document.querySelector(location.hash);
    if (element) {
      element.scrollIntoView();
      // Scroll a bit more due to the header
      setTimeout(function () {
        window.scrollBy(0, -50);
      }, 20);
    }
  }
});
