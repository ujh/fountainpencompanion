$(function() {
  var element = $(location.hash).get(0) || $(window.elementToScrollTo).get(0);
  if (element) element.scrollIntoView();
})
