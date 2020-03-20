import React from "react";
import ReactDOM from "react-dom";

import { App } from "./App";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("micro-clusters-app");
  ReactDOM.render(<App />, el);
});
