$(function () {
  $(
    "#currently_inked_collected_pen_id, #currently_inked_collected_ink_id"
  ).select2({
    width: "100%",
  });

  $("#currently_inked_inked_on, #currently_inked_archived_on").datepicker({
    dateFormat: "yy-mm-dd",
  });

  $("#currently-inked .actions .usage").bind("ajax:complete", function () {
    $(this)
      .addClass("btn-outline-secondary")
      .removeClass("btn-primary-secondary")
      .find("i")
      .addClass("fa-bookmark-o")
      .removeClass("fa-bookmark");
    $(this).attr("title", "Already recorded usage for today");
    clicky.log("#usage-record", "CI usage recorded");
  });
});
