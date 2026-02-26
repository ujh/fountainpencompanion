import React from "react";
import { createRoot } from "react-dom/client";
import { App } from "./app";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".fpc-edit-colors");
  Array.from(elements).forEach((el) => {
    const colors = JSON.parse(el.dataset.colors);
    const ignoredColors = JSON.parse(el.dataset.ignoredColors);
    const root = createRoot(el);
    root.render(
      <App
        colors={colors}
        ignoredColors={ignoredColors}
        submitUrl={el.dataset.submitUrl}
        cancelUrl={el.dataset.cancelUrl}
        currentColor={el.dataset.currentColor}
        csrfToken={el.dataset.csrfToken}
      />
    );
  });
});
