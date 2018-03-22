import * as React from "react";

class Kind extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      editing: false
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

  onBlur() {
    this.setState({editing: false})
  }

  onSelectChanged(event) {
    this.setState({editing: false})
    this.props.onChange(event.target.value)
  }

  onKeyDown(e) {
    // This is only executed when the select is closed!
    const code = e.keyCode;
    if (code === 13) { // Enter
      this.setState({editing: false})
    } else if (code === 27) { // Escape
      this.setState({editing: false})
    }
  }

  renderEditView() {
    // TODO: Handle pressing of the escape and enter (?) keys
    return <span>
      <select
        value={this.props.kind}
        onBlur={() => this.onBlur()}
        onChange={(e) => this.onSelectChanged(e)}
        onKeyDown={(e) => this.onKeyDown(e)}
      >
        <option></option>
        <option>bottle</option>
        <option>sample</option>
        <option>cartridge</option>
      </select>
    </span>;
  }

  renderDefaultView() {
    const displayValue = this.props.kind || <span>&nbsp;</span>;
    return <div className="editable" onClick={() => this.setState({editing: true})}>
      {displayValue}
    </div>;
  }
}

export default Kind;
