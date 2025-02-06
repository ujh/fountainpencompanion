import React from "react";
import { createRoot } from "react-dom/client";
import { App } from "./app";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".fpc-add-ink-button");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(<App macro_cluster_id={el.dataset.macroClusterId} details={el.dataset.details} />);
  });
});
