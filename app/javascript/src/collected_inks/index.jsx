import * as React from "react";
import * as ReactDOM from "react-dom";
import { Provider } from "react-redux";

import { fetchData } from "./actions";
import store from "./store";
import App from "./app";

export const renderCollectedInks = (el) => {
  const appStore = store();
  ReactDOM.render(<Provider store={appStore}><App /></Provider>, el)
  appStore.dispatch(fetchData())
};


import renderColorPickerApp from "./color_picker";
export { renderColorPickerApp };
