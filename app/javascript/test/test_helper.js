// Make useful test functions available globally.
import { expect } from "chai";
import { spy, stub } from "sinon";

window.expect = expect;
window.spy = spy;
window.stub = stub;

import * as React from "react";
window.React = React;

let requireAll = requireContext => {
  requireContext.keys().forEach(requireContext);
};

// require all js files except test_helper.js in the test folder
requireAll(require.context("./", true, /^((?!test_helper).)*\.jsx?$/));

// require all component js files in the src folder
requireAll(require.context("../src/", true, /\.jsx?$/));
