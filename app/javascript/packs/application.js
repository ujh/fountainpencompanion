/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb

import "../stylesheets/application.scss";
require.context("../images", true);

import "core-js/stable";
import "regenerator-runtime/runtime";
import { Tooltip, Dropdown } from "bootstrap";
import "@popperjs/core";

import "../src/color-picker";
import "../src/collected_inks";
import "../src/dashboard";
import "../src/add-ink-button";
import "../src/ink-search-hint";
import { renderFriendButton } from "../src/friends";
import renderPublicInks from "../src/public_inks";
import setTimeZone from "../src/setTimeZone";

window.renderPublicInks = renderPublicInks;
window.renderFriendButton = renderFriendButton;
window.setTimeZone = setTimeZone;

[...document.querySelectorAll('[data-bs-toggle="tooltip"]')].map(
  (triggerEl) => new Tooltip(triggerEl)
);

[...document.querySelectorAll('[data-bs-toggle="dropdown"]')].map(
  (triggerEl) => new Dropdown(triggerEl)
);
