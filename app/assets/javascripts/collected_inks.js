$(function() {
  $('#collected-ink-form #collected_ink_manufacturer_name').autocomplete({
    source: "/manufacturers"
  })
})
