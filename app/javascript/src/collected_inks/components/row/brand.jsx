import * as React from "react";
import { connect } from "react-redux";

import FancyInput from "./fancy_input";

class Brand extends FancyInput {
  constructor(props) {
    super(props);
  }

  valueFieldName() {
    return "brand";
  }

  required() {
    return true;
  }
}

const mapStateToProps = ({suggestions}) => ({suggestions: suggestions.brands});

const mapDispatchToProps = (_) => ({});

export default connect(mapStateToProps, mapDispatchToProps)(Brand);
