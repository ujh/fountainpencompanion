document.addEventListener("click", function (event) {
  var btn = event.target.closest(".reject-btn");
  if (!btn) return;
  var form = btn.closest("form.reject-form");
  if (!form) return;
  var note = form.querySelector(".reject-note");
  if (!note) return;
  if (note.dataset.shown === "true") return;
  event.preventDefault();
  note.style.cssText = "";
  note.dataset.shown = "true";
  note.focus();
});
