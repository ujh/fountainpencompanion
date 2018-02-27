import * as React from "react";
import * as ReactDOM from "react-dom";
import { Provider } from "react-redux";

import store from "./store";
import App from "./app";

export const renderCollectedInks = (el) => {
  ReactDOM.render(<Provider store={store()}><App /></Provider>, el)
};


import renderColorPickerApp from "./color_picker";
export { renderColorPickerApp };
