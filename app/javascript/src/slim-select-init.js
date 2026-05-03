import SlimSelect from "slim-select";
import "slim-select/styles";

document.addEventListener("DOMContentLoaded", () => {
  const penSelect = document.getElementById("currently_inked_collected_pen_id");
  const inkSelect = document.getElementById("currently_inked_collected_ink_id");

  const config = {
    allowDeselect: true,
    closeOnSelect: true
  };

  if (penSelect) {
    penSelect.classList.remove("form-control", "form-select");
    new SlimSelect({
      select: penSelect,
      settings: {
        ...config,
        placeholderText: "(Pick a pen)"
      }
    });
  }

  if (inkSelect) {
    inkSelect.classList.remove("form-control", "form-select");
    new SlimSelect({
      select: inkSelect,
      settings: {
        ...config,
        placeholderText: "(Pick an ink)"
      }
    });
  }
});
