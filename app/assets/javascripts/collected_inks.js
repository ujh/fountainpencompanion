$(function() {
  $("#collected-inks-app").each(function() {
    renderCollectedInks(this);
  });

  $("#collected-inks-beta .app").each(function() {
    renderCollectedInksBeta(this);
  });

  $("#collected_ink_brand_name").autocomplete({
    source: function(request, response) {
      fetch("/brands?term=" + request.term)
        .then(function(r) {
          return r.json();
        })
        .then(function(r) {
          var names = $.map(r.data, function(e) {
            return e.attributes.popular_name;
          });
          response(names);
        });
    }
  });

  $("#collected_ink_line_name").autocomplete({
    source: "/lines"
  });

  $("#collected_ink_ink_name").autocomplete({
    source: "/inks"
  });
});
