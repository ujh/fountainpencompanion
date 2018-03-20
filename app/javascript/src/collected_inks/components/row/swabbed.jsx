import * as React from "react";

const Swabbed = ({swabbed, onClick}) => {
  const className = `swabbed ${swabbed}`;
  const icon = swabbed ? "check" : "times";
  return <div className={className} onClick={onClick}>
    <span className="editable"><i className={`fa fa-${icon}`}></i></span>
  </div>;
};

export default Swabbed;
