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

  renderEditView() {
    // TODO: Add an overlay div (see the color picker) to handle the case where the user selects
    //       the same option. Alternatively check if using onclick would work. Look into riek!
    return <span>
      <select value={this.props.kind} onBlur={() => this.onBlur()} onChange={(e) => this.onSelectChanged(e)}>
        <option></option>
        <option>bottle</option>
        <option>sample</option>
        <option>cartridge</option>
      </select>
    </span>;
  }

  renderDefaultView() {
    const displayValue = this.props.kind || "NOT SET"
    return <span className="editable" onClick={() => this.setState({editing: true})}>
      {displayValue}
    </span>;
  }
}

export default Kind;
