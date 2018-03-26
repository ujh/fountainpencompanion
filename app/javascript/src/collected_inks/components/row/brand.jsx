import * as React from "react";

import NonEmptyInput from "./non_empty_input";

class Brand extends NonEmptyInput {
  constructor(props) {
    super(props);
  }

  valueFieldName() {
    return "brand";
  }

}

export default Brand;
