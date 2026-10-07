export function setupLineNameToggle() {
  const checkbox = document.getElementById("macro_cluster_line_name_is_empty");
  const input = document.getElementById("manual_line_name_input");
  if (!checkbox || !input) return;

  checkbox.addEventListener("change", () => {
    input.disabled = checkbox.checked;
    if (checkbox.checked) input.value = "";
  });
}
