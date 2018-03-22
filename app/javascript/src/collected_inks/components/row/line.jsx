import * as React from "react";

class Line extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      editing: false,
      value: props.line
    };
  }

  editing() {
    return this.state.editing;
  }

  render() {
    if (this.editing()) {
      return this.renderEditView();
    } else {
      return this.renderDefaultView();
    }
  }

  onChange(e) {
    this.setState({value: e.target.value})
  }

  onBlur() {
    this.finishedEditing()
  }

  onKeyDown(e) {
    const code = e.keyCode;
    if (code === 13) { // Enter
      this.finishedEditing()
    } else if (code === 27) { // Escape
      this.setState({
        editing: false,
        value: this.props.line
      })
    }
  }

  onFocus(e) {
    e.target.select();
  }

  finishedEditing() {
    this.setState({editing: false});
    this.props.onChange(this.state.value);
  }

  renderEditView() {
    return <input
      type="text"
      value={this.state.value}
      onBlur={(e) => this.onBlur(e)}
      onKeyDown={(e) => this.onKeyDown(e)}
      onChange={(e) => this.onChange(e)}
      onFocus={(e) => this.onFocus(e)}
      autoFocus
    />
  }

  renderDefaultView() {
    const displayValue = this.state.value || <span>&nbsp;</span>;
    return <div className="editable" onClick={() => this.setState({editing: true})}>
      {displayValue}
    </div>;
  }
}

export default Line;
