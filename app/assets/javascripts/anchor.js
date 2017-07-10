$(function() {
  var element = $(location.hash).get(0) || $(window.elementToScrollTo).get(0);
  if (element) {
    element.scrollIntoView();
    // Scroll a bit more due to the header
    setTimeout(function() {
      window.scrollBy(0, -50);
    }, 20)
  }

  if (location.hash === "#add-form") {
    setTimeout(function() {
      $('#collected_ink_brand_name').get(0).focus()
    }, 20)
  }
})
