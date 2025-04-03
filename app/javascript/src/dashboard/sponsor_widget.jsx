import React from "react";
import { Widget } from "./widgets";

export const SponsorWidget = ({ renderWhenInvisible }) => (
  <Widget header="Corporate Sponsors" renderWhenInvisible={renderWhenInvisible}>
    <div className="row">
      <div className="col-sm-6">content 1</div>
      <div className="col-sm-6">content 2</div>
    </div>
    <div className="row">
      <div className="col-sm-6">content 3</div>
      <div className="col-sm-6">content 4</div>
    </div>
  </Widget>
);
