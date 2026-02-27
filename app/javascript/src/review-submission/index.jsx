import React from "react";
import { createRoot } from "react-dom/client";
import { App } from "./app";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".fpc-review-submission");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(<App url={el.dataset.url} />);
  });
});
