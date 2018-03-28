import * as React from "react";
import { connect } from "react-redux";

import FancyInput from "./fancy_input";

class Ink extends FancyInput {
  constructor(props) {
    super(props);
  }

  valueFieldName() {
    return "ink";
  }

  required() {
    return true;
  }

}

const mapStateToProps = ({suggestions}) => ({suggestions: suggestions.inks});

const mapDispatchToProps = (_) => ({});

export default connect(mapStateToProps, mapDispatchToProps)(Ink);
