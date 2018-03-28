import * as React from "react";

const Used = ({used, onClick}) => {
  const className = `used ${used}`;
  const icon = used ? "check" : "times";
  return <div className={className} onClick={onClick}>
    <span className="editable"><i className={`fa fa-${icon}`}></i></span>
  </div>;
};

export default Used;
