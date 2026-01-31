import "./stylesheets/application.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";
import "./src/select2-init";
import { Tooltip, Dropdown } from "bootstrap";
import "@popperjs/core";

import "./color-mode";
import "./src/color-picker";
import "./src/collected_inks";
import "./src/collected_pens";
import "./src/currently_inked";
import "./src/dashboard";
import "./src/add-ink-button";
import "./src/ink-search-hint";
import "./src/public_inks";
import "./src/collected-inks-autocomplete";
import "./src/collected-pens-autocomplete";
import setTimeZone from "./src/setTimeZone";

window.setTimeZone = setTimeZone;

[...document.querySelectorAll('[data-bs-toggle="tooltip"]')].map(
  (triggerEl) => new Tooltip(triggerEl)
);

[...document.querySelectorAll('[data-bs-toggle="dropdown"]')].map(
  (triggerEl) => new Dropdown(triggerEl)
);
