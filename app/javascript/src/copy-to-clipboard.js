function copyTextFor(target) {
  return target instanceof HTMLInputElement ? target.value : target.textContent;
}

export function setupCopyButtons(root = document) {
  root.addEventListener("click", (event) => {
    const button = event.target.closest("[data-copy-target]");
    if (!button) return;

    const target = document.getElementById(button.dataset.copyTarget);
    if (!target) return;

    navigator.clipboard.writeText(copyTextFor(target));
    button.textContent = "Copied!";
  });
}
