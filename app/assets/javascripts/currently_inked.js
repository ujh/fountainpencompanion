$(function () {
  $("#currently-inked .actions .usage").bind("ajax:complete", function () {
    $(this).find("i").addClass("fa-bookmark-o").removeClass("fa-bookmark");
    $(this).attr("title", "Already recorded usage for today");
    clicky.log("#usage-record", "CI usage recorded");
  });
});
