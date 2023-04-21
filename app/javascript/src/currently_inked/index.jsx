/* istanbul ignore file */
import React from "react";
import { createRoot } from "react-dom/client";
import { CurrentlyInked } from "./CurrentlyInked";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll("#currently-inked-app");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(<CurrentlyInked />);
  });
});
