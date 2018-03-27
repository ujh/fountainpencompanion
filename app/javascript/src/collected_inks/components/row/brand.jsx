import * as React from "react";
import { connect } from "react-redux";

import NonEmptyInput from "./non_empty_input";

class Brand extends NonEmptyInput {
  constructor(props) {
    super(props);
  }

  valueFieldName() {
    return "brand";
  }

}

const mapStateToProps = ({suggestions}) => ({suggestions: suggestions.brands});

const mapDispatchToProps = (_) => ({});

export default connect(mapStateToProps, mapDispatchToProps)(Brand);
