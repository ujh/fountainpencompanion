import * as React from "react";
import * as ReactDOM from "react-dom";
import { ChromePicker } from "react-color";

export function renderColorPickerApp(element) {
  let input = $(element).find('input');
  let initialColor = input.val() || "#000";
  ReactDOM.render(<App color={initialColor} />, element);
}

const App = ({color}) => {
  return <div style={{backgroundColor: color}}>
    {color}
    <ColorInput color={color} />
  </div>;
}

const ColorInput = ({color}) => {
  return <div>
    <input type="hidden" name="collected_ink[color]" value={color} />
  </div>;
}
