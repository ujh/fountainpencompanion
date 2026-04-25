import "@popperjs/core";
import Rails from "@rails/ujs";
import { Dropdown, Tooltip } from "bootstrap";
import "core-js/stable";
import "regenerator-runtime/runtime";
import "./color-mode";
import "./src/add-ink-button";
import "./src/collected-inks-autocomplete";
import "./src/collected-pens-autocomplete";
import "./src/collected_inks";
import "./src/collected_pens";
import "./src/color-picker";
import "./src/currently_inked";
import "./src/dashboard";
import "./src/edit-colors";
import "./src/ink-search-hint";
import "./src/public_inks";
import "./src/review-submission";
import setTimeZone from "./src/setTimeZone";
import "./src/slim-select-init";
import "./src/usage_records";
import "./stylesheets/application.scss";

Rails.start();

window.setTimeZone = setTimeZone;

[...document.querySelectorAll('[data-bs-toggle="tooltip"]')].map(
  (triggerEl) => new Tooltip(triggerEl)
);

[...document.querySelectorAll('[data-bs-toggle="dropdown"]')].map(
  (triggerEl) => new Dropdown(triggerEl)
);
