import * as React from "react";

import NonEmptyInput from "./non_empty_input";

class Comment extends NonEmptyInput {
  constructor(props) {
    super(props);
  }

  valueFieldName() {
    return "comment";
  }

  required() {
    return false;
  }

}

export default Comment;
