$(function() {
  $('#collected-pen-form #collected_pen_brand').autocomplete({
    source: "/pens/brands"
  })
  $('#collected-pen-form #collected_pen_model').autocomplete({
    source: "/pens/models"
  })
})
