import TomSelect from "tom-select";
import "tom-select/dist/css/tom-select.bootstrap5.css";

document.addEventListener("DOMContentLoaded", () => {
  const penSelect = document.getElementById("currently_inked_collected_pen_id");
  const inkSelect = document.getElementById("currently_inked_collected_ink_id");

  const config = {
    create: false,
    sortField: {
      field: "text",
      direction: "asc"
    }
  };

  if (penSelect) {
    new TomSelect(penSelect, config);
  }

  if (inkSelect) {
    new TomSelect(inkSelect, config);
  }
});
