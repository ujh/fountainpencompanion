import * as React from "react";

class FancyInput extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      editing: this.defaultEditing(),
      value: this.value()
    };
  }

  componentDidUpdate(prevProps) {
    if (prevProps[this.valueFieldName()] != this.value()) {
      this.setState({value: this.value()})
    }
  }

  defaultEditing() {
    if (this.props.onlyEdit) {
      return true;
    }
    return false;
  }

  required() {
    throw "Implement in subclass";
  }

  value() {
    return this.props[this.valueFieldName()]
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
    switch (code) {
      case 9: // Tab
        if (this.autoFocus()) e.preventDefault();
        this.finishedEditing();
        return;
      case 13: // Enter
        this.finishedEditing();
        return;
      case 27: // Escape
        this.cancelEditing();
        return;
    }
  }

  onFocus(e) {
    e.target.select();
  }

  cancelEditing() {
    this.setState({
      editing: this.defaultEditing(),
      value: this.value()
    })
  }

  finishedEditing() {
    if (this.required()) {
      if (this.state.value) {
        this.setState({editing: this.defaultEditing()});
        this.props.onChange(this.state.value);
      } else {
        this.cancelEditing()
      }
    } else {
      this.setState({editing: this.defaultEditing()});
      this.props.onChange(this.state.value);
    }
  }

  autoFocus() {
    if (this.props.onlyEdit) {
      return false;
    }
    return true;
  }

  renderEditView() {
    return this.renderInputComponent({
      autoFocus: this.autoFocus(),
      suggestions: this.props.suggestions,
      value: this.state.value,
      onBlur: (e) => this.onBlur(e),
      onKeyDown: (e) => this.onKeyDown(e),
      onChange: (e) => this.onChange(e),
      onFocus: (e) => this.onFocus(e),
    })
  }

  renderInputComponent(inputProps) {
    let className = "form-group"
    let help = null;
    if (this.required() && !this.state.value) {
      className += " has-error"
      help = <span className="help-block">required</span>
    }
    return <div className={className}>
      <InputComponent {...inputProps} />
      { help }
    </div>;
  }

  renderDefaultView() {
    const displayValue = this.state.value || <span>&nbsp;</span>;
    return <div className="editable" onClick={() => this.setState({editing: true})}>
      {displayValue}
    </div>;
  }
}

class InputComponent extends React.Component {

  withAutocomplete() {
    return !!this.props.suggestions
  }

  render() {
    if (this.withAutocomplete()) {
      return this.renderWithAutocomplete()
    } else {
      return this.renderWithoutAutocomplete()
    }
  }

  renderWithoutAutocomplete() {
    return <input
      type="text"
      className="form-control"
      {...this.props}
    />
  }

  renderWithAutocomplete() {
    return <input
      type="text"
      className="form-control"
      ref={i => this.input = i}
      defaultValue={this.props.value}
      onBlur={this.props.onBlur}
      onKeyDown={this.props.onKeyDown}
    />
  }

  componentDidMount() {
    if (this.props.suggestions) this.setupAutocomplete()
  }

  componentDidUpdate() {
    if (this.props.suggestions) {
      $(this.input).autocomplete("option", "source", this.props.suggestions)
    }
  }

  setupAutocomplete() {
    $(this.input).autocomplete({
      source: this.props.suggestions
    })
    $(this.input).on("autocompletechange", (e) => {
      // Otherwise clicking on an autocomplete entry won't work
      setTimeout(() => {
        this.props.onChange(e)
        this.props.onBlur(e)
      }, 0)
    })
    if (this.props.autoFocus) this.input.select()
  }
}

export default FancyInput;
