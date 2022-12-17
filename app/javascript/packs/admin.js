import "../stylesheets/admin.scss";
require.context("../images", true);

import "core-js/stable";
import "regenerator-runtime/runtime";
import { Tooltip, Dropdown } from "bootstrap";
import "@popperjs/core";

import "../src/admin/micro-clusters";
import "../src/admin/graphs";

[...document.querySelectorAll('[data-bs-toggle="tooltip"]')].map(
  (triggerEl) => new Tooltip(triggerEl)
);

[...document.querySelectorAll('[data-bs-toggle="dropdown"]')].map(
  (triggerEl) => new Dropdown(triggerEl)
);
