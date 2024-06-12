import "./stylesheets/admin.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";
import { Tooltip, Dropdown } from "bootstrap";
import "@popperjs/core";

import "./color-mode";
import "./src/admin/micro-clusters";
import "./src/admin/pens-micro-clusters";
import "./src/admin/pens-model-micro-clusters";
import "./src/admin/graphs";

[...document.querySelectorAll('[data-bs-toggle="tooltip"]')].map(
  (triggerEl) => new Tooltip(triggerEl)
);

[...document.querySelectorAll('[data-bs-toggle="dropdown"]')].map(
  (triggerEl) => new Dropdown(triggerEl)
);
