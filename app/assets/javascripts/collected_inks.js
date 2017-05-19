$(function() {
  $('#collected-ink-form #collected_ink_manufacturer_name').autocomplete({
    source: "/manufacturers"
  })
  $('#collected-ink-form #collected_ink_ink_name').autocomplete({
    source: "/inks"
  })
})
