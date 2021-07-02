$(function () {
  $("#collected_pen_brand").autocomplete({
    source: "/pens/brands",
  });
  $("#collected_pen_model").autocomplete({
    source: "/pens/models",
  });
});
