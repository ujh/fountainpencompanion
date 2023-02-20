/* istanbul ignore file */
import React from "react";
import { createRoot } from "react-dom/client";
import { CollectedInks } from "./CollectedInks";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll("#collected-inks .app");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(
      <CollectedInks archive={el.getAttribute("data-archive") == "true"} />
    );
  });
});
