import * as React from "react";

import NonEmptyInput from "./non_empty_input";

class Line extends NonEmptyInput {
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

export default Line;
