import React from "react";
import { createRoot } from "react-dom/client";

import { App } from "./App";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("micro-clusters-app");
  if (el) {
    const root = createRoot(el);
    root.render(<App />);
  }
});
