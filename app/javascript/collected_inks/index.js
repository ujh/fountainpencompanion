import * as React from "react";
import * as ReactDOM from "react-dom";
import { ChromePicker } from "react-color";

export function renderColorPickerApp(element) {
  console.log(element)
  let initialColor = $(element).val();
  console.log(initialColor);
}
