$(function() {
  $('#collected-ink-form #collected_ink_brand_name').autocomplete({
    source: "/brands"
  })
  $('#collected-ink-form #collected_ink_line_name').autocomplete({
    source: "/lines"
  })
  $('#collected-ink-form #collected_ink_ink_name').autocomplete({
    source: "/inks"
  })
})
