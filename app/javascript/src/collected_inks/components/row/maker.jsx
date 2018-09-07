import * as React from "react";

import FancyInput from "./fancy_input";

class Maker extends FancyInput {
  constructor(props) {
    super(props);
  }

  valueFieldName() {
    return "maker";
  }

  required() {
    return false;
  }

}

export default Maker;
