import * as React from "react";
import { connect } from "react-redux";

import FancyInput from "./fancy_input";

class Line extends FancyInput {
  constructor(props) {
    super(props);
  }

  valueFieldName() {
    return "line";
  }

  required() {
    return false;
  }

}

const mapStateToProps = ({suggestions}) => ({suggestions: suggestions.lines});

const mapDispatchToProps = (_) => ({});

export default connect(mapStateToProps, mapDispatchToProps)(Line);
