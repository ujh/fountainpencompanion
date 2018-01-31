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

  handleClose() {
    this.setState({displayColorPicker: false})
  }

  renderColorPicker() {
    if (!this.state.displayColorPicker) return;
    let color = this.state.color;
    return <ColorPicker
      color={color}
      onChange={ (c) => this.handleChange(c)}
      onClose= { () => this.handleClose() }
    />;
  }

  render() {
    let color = this.state.color;
    return <div>
      <Button color={color} onClick={ () => this.handleClick() }/>
      { this.renderColorPicker() }
      <ColorInputField color={color} />
    </div>;
  }
}

const ColorPicker = ({color, onChange, onClose}) => {
  let outerCSS = {
    position: 'absolute',
    zIndex: 2
  };
  let overlayCSS = {
    position: 'fixed',
    top: '0px',
    left: '0px',
    right: '0px',
    bottom: '0px',
  };
  return <div style={outerCSS}>
    <div style={overlayCSS} onClick={onClose}></div>
    <ChromePicker color={color} onChange={onChange} disableAlpha={true}/>
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
