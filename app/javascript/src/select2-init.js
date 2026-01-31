import $ from "jquery";
import "select2";

document.addEventListener("DOMContentLoaded", () => {
  const penSelect = document.getElementById("currently_inked_collected_pen_id");
  const inkSelect = document.getElementById("currently_inked_collected_ink_id");

  if (penSelect || inkSelect) {
    $("#currently_inked_collected_pen_id, #currently_inked_collected_ink_id").select2({
      width: "100%"
    });
  }
});
