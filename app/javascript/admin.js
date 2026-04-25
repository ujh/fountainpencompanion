import "@popperjs/core";
import Rails from "@rails/ujs";
import { Dropdown, Tooltip } from "bootstrap";
import "core-js/stable";
import "regenerator-runtime/runtime";
import "./color-mode";
import "./src/admin/graphs";
import "./src/admin/micro-clusters";
import "./src/admin/pens-micro-clusters";
import "./src/admin/pens-model-micro-clusters";
import "./src/admin/stats";
import "./stylesheets/admin.scss";

Rails.start();

[...document.querySelectorAll('[data-bs-toggle="tooltip"]')].map(
  (triggerEl) => new Tooltip(triggerEl)
);

[...document.querySelectorAll('[data-bs-toggle="dropdown"]')].map(
  (triggerEl) => new Dropdown(triggerEl)
);
