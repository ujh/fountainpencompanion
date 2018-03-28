import * as React from "react";

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

export default Ink;
