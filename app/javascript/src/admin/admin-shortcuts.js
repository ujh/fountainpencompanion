var SHORTCUTS = {
  a: "approve",
  r: "reject",
  d: "reject-delete",
  s: "search"
};

document.addEventListener("keydown", function (event) {
  if (event.metaKey || event.ctrlKey || event.altKey) return;
  var target = event.target;
  if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) return;
  var shortcut = SHORTCUTS[event.key.toLowerCase()];
  if (!shortcut) return;
  var el = document.querySelector('[data-shortcut="' + shortcut + '"]');
  if (!el) return;
  event.preventDefault();
  el.click();
});
