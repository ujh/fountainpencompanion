import * as React from "react";
import * as ReactDOM from "react-dom";
import { ChromePicker } from "react-color";

export function renderColorPickerApp(element) {
  let input = $(element).find('input');
  let initialColor = input.val() || "#fff";
  ReactDOM.render(<App color={initialColor} />, element);
}

class App extends React.Component {

  constructor(props) {
    super(props);
    this.state = {
      displayColorPicker: false,
      color: props.color
    }
  }

  render() {
    let color = this.state.color;
    return <div style={{backgroundColor: color}}>
      {color}
      <ColorInputField color={color} />
    </div>;
  }
}

const ColorInputField = ({color}) => {
  return <div>
    <input type="hidden" name="collected_ink[color]" value={color} />
  </div>;
}
