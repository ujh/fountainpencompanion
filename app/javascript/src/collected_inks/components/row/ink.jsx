import * as React from "react";

import NonEmptyInput from "./non_empty_input";

class Ink extends NonEmptyInput {
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
