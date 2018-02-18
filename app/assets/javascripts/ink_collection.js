$(function() {
  $('.ink-collection').each(function(){
    filterFor($(this));
  });
})

function filterFor(base) {
  if (!base.length) return;
  var rows = base.find('tbody tr[data-name=entry]');
  var brandsSelector = base.find('.filters select[name=brands]');
  brandsSelector.on('change', function() {
    var selectedBrand = brandsSelector.val();
    if (selectedBrand) {
      rows.each(function() {
        var el = $(this);
        if (el.find('[data-name=brand_name]').text() == selectedBrand) {
          el.show();
        } else {
          el.hide();
        }
      })
    } else {
      rows.show();
    }
  })
}
