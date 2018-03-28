import * as React from "react";

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

export default Line;
