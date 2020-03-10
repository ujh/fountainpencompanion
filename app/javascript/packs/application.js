/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb

// Needs to come first. http://babeljs.io/docs/usage/polyfill/
import "babel-polyfill";
// Promise polyfill. https://github.com/taylorhakes/promise-polyfill
import Promise from "promise-polyfill";
// To add to window
if (!window.Promise) {
  window.Promise = Promise;
}
// fetch polyfill. https://github.com/github/fetch
import "whatwg-fetch";

import "../src/color-picker";
import {
  renderCollectedInks,
  renderCollectedInksBeta
} from "../src/collected_inks";
import renderPublicInks from "../src/public_inks";

window.renderCollectedInks = renderCollectedInks;
window.renderCollectedInksBeta = renderCollectedInksBeta;
window.renderPublicInks = renderPublicInks;
