import React, { useState, useEffect } from "react";
import * as ReactDOM from "react-dom";
import { getRequest } from "src/fetch";

export const renderCollectedInksBeta = el => {
  ReactDOM.render(<CollectedInksBeta />, el);
};

export default renderCollectedInksBeta;

const CollectedInksBeta = () => {
  const [inks, setInks] = useState();
  useEffect(() => {
    getRequest("/collected_inks.json")
      .then(response => response.json())
      .then(json => setInks(json.data));
  }, []);
  if (inks) {
    console.log(inks);
    return <div></div>;
  } else {
    return <div>Loading ...</div>;
  }
};
