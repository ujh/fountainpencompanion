import React from "react";

export const Spinner = ({ text }) => (
  <div className="loader">
    <i className="fa fa-spin fa-refresh" />
    <div>{text}</div>
  </div>
);
