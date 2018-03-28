import * as React from "react";

const Privacy = (props) => {
  const icon = props.private ? "lock" : "unlock";
  return <div onClick={props.onClick}>
    <span className="editable"><i className={`fa fa-${icon}`}></i></span>
  </div>;
}

export default Privacy;
