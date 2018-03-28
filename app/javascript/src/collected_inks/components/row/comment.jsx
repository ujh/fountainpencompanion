import * as React from "react";

import FancyInput from "./fancy_input";

class Comment extends FancyInput {
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
