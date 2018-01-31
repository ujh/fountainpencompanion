import * as React from "react";
import * as ReactDOM from "react-dom";
import { ChromePicker } from "react-color";

export function renderColorPickerApp(element) {
  let input = $(element).find('input');
  let initialColor = input.val() || "#000";
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

  handleClick() {
    this.setState({displayColorPicker: !this.state.displayColorPicker})
  }

  handleChange(color) {
    this.setState({color: color.hex});
  }

  render() {
    let color = this.state.color;
    return <div>
      <Button color={color} onClick={ () => this.handleClick() }/>
      { this.state.displayColorPicker ? <ColorPicker color={color} onChange={ (c) => this.handleChange(c)}/> : ""}
      <ColorInputField color={color} />
    </div>;
  }
}

const ColorPicker = ({color, onChange}) => {
  let outerCSS = {
    position: 'absolute',
    zIndex: 2
  };
  return <div style={outerCSS}>
    <ChromePicker color={color} onChange={onChange}/>
  </div>;
}

const Button = ({color, onClick}) => {
  let outerCSS = {
    padding: '5px',
    background: '#fff',
    borderRadius: '1px',
    boxShadow: '0 0 0 1px rgba(0,0,0,.1)',
    display: 'inline-block',
    cursor: 'pointer',
  }
  let innerCSS = {
    width: '36px',
    height: '23px',
    borderRadius: '2px',
    boxShadow: '0 0 0 1px rgba(0,0,0,.1)',
    backgroundColor: color,
  };
  return <div onClick={onClick} style={outerCSS}><div style={innerCSS}></div></div>;
}

const ColorInputField = ({color}) => {
  return <div>
    <input type="hidden" name="collected_ink[color]" value={color} />
  </div>;
}
