$(function () {
  var element = $(location.hash).get(0);
  if (element) {
    element.scrollIntoView();
    // Scroll a bit more due to the header
    setTimeout(function () {
      window.scrollBy(0, -50);
    }, 20);
  }
});
