import React from "react";
import * as ReactDOM from "react-dom";
import { App } from "./app";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".add-ink-button");
  Array.from(elements).forEach((el) => {
    ReactDOM.render(<App macro_cluster_id={el.dataset.macroClusterId} />, el);
  });
});
