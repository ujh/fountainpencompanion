document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll("#currently-inked .actions .usage").forEach(function (el) {
    el.addEventListener("ajax:complete", function () {
      var icon = this.querySelector("i");
      if (icon) {
        icon.classList.add("fa-bookmark-o");
        icon.classList.remove("fa-bookmark");
      }
      this.setAttribute("title", "Already recorded usage for today");
      clicky.log("#usage-record", "CI usage recorded");
    });
  });
});
