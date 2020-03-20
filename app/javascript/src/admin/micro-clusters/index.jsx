import React from "react";
import ReactDOM from "react-dom";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("micro-clusters-app");
  ReactDOM.render(<MicroClustersApp />, el);
});

const MicroClustersApp = () => (
  <div className="app">
    <div className="nav">
      <i className="fa fa-angle-left"></i>
    </div>
    <div className="main">
      <div className="loader">
        <i className="fa fa-spin fa-refresh" />
      </div>
    </div>
    <div className="nav">
      <i className="fa fa-angle-right"></i>
    </div>
  </div>
);
