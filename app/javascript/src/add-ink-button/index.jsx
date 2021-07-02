import React from "react";
import { useState } from "react";
import * as ReactDOM from "react-dom";
import { useEffect } from "react/cjs/react.development";
import { getRequest, postRequest } from "../fetch";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".add-ink-button");
  Array.from(elements).forEach((el) => {
    ReactDOM.render(<App macro_cluster_id={el.dataset.macroClusterId} />, el);
  });
});

const App = ({ macro_cluster_id }) => {
  const [loading, setLoading] = useState(true);
  const [inCollection, setInCollection] = useState(false);
  useEffect(() => {
    getRequest(
      `/collected_inks.json?filter[macro_cluster_id]=${macro_cluster_id}`
    )
      .then((response) => response.json())
      .then((json) => {
        setInCollection(json.data.length > 0);
        setLoading(false);
      });
  }, []);
  if (loading) {
    return <Loader />;
  } else if (inCollection) {
    // Add a hidden button to make the table row the same height as the others
    return (
      <div className="btn" style={{ visibility: "hidden" }}>
        &nbsp;
      </div>
    );
  } else {
    return <ActualInkAddButton macro_cluster_id={macro_cluster_id} />;
  }
};

const ActualInkAddButton = ({ macro_cluster_id }) => {
  const [state, setState] = useState(null);
  const [kind, setKind] = useState("bottle");
  const add = () => {
    setState("adding");
    postRequest(
      `/collected_inks/add.json?macro_cluster_id=${macro_cluster_id}&kind=${kind}`
    ).then(() => {
      setState("added");
    });
  };
  switch (state) {
    case "added":
      return (
        <div className="btn btn-default">
          <i className="fa fa-check" />
        </div>
      );
    case "adding":
      return (
        <div className="btn btn-default">
          <Loader />
        </div>
      );
    case "pick-kind":
      return (
        <div className="pick-kind">
          <span>Type:</span>
          <span>
            <select value={kind} onChange={(e) => setKind(e.target.value)}>
              <option value="bottle">bottle</option>
              <option value="sample">sample</option>
              <option value="cartridge">cartridge</option>
            </select>
          </span>
          <span className="btn btn-primary" onClick={add}>
            Add
          </span>
          <span className="btn btn-default" onClick={() => setState(null)}>
            <i className="fa fa-times" />
          </span>
        </div>
      );
    default:
      return (
        <div className="btn btn-default" onClick={() => setState("pick-kind")}>
          Add to collection
        </div>
      );
  }
};

const Loader = () => (
  <div className="loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);
