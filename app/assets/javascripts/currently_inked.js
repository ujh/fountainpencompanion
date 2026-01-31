$(function () {
  $("#currently_inked_collected_pen_id, #currently_inked_collected_ink_id").select2({
    width: "100%"
  });

  $("#currently-inked .actions .usage").bind("ajax:complete", function () {
    $(this).find("i").addClass("fa-bookmark-o").removeClass("fa-bookmark");
    $(this).attr("title", "Already recorded usage for today");
    clicky.log("#usage-record", "CI usage recorded");
  });
});
