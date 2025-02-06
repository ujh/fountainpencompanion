import React from "react";
import { useState, useEffect } from "react";
import { getRequest, postRequest } from "../fetch";

export const App = ({ macro_cluster_id, details }) => {
  const [loading, setLoading] = useState(true);
  const [inCollection, setInCollection] = useState(false);
  useEffect(() => {
    getRequest(`/collected_inks.json?filter[macro_cluster_id]=${macro_cluster_id}`)
      .then((response) => response.json())
      .then((json) => {
        setInCollection(json.data.length > 0);
        setLoading(false);
      });
  }, [macro_cluster_id]);
  if (loading) {
    return <Loader />;
  } else {
    return (
      <ActualInkAddButton
        macro_cluster_id={macro_cluster_id}
        inCollection={inCollection}
        detailView={details}
      />
    );
  }
};

const ActualInkAddButton = ({ macro_cluster_id, inCollection, detailView }) => {
  const [state, setState] = useState(null);
  const [kind, setKind] = useState("bottle");
  const add = () => {
    setState("adding");
    postRequest(`/collected_inks/add.json?macro_cluster_id=${macro_cluster_id}&kind=${kind}`).then(
      () => {
        setState("added");
      }
    );
  };
  switch (state) {
    case "added":
      return (
        <button disabled className="btn btn-outline-success">
          <i className="fa fa-check" />
        </button>
      );
    case "adding":
      return (
        <button disabled className="btn btn-secondary">
          <Loader />
        </button>
      );
    case "pick-kind":
      return (
        <div className="pick-kind">
          <select
            aria-label="Type"
            className="form-select"
            style={{ minWidth: "100px" }}
            value={kind}
            onChange={(e) => setKind(e.target.value)}
          >
            <option value="bottle">bottle</option>
            <option value="sample">sample</option>
            <option value="cartridge">cartridge</option>
            <option value="swab">swab</option>
          </select>
          <button type="button" className="btn btn-success" onClick={add}>
            Add
          </button>
          <button type="button" className="btn btn-secondary" onClick={() => setState(null)}>
            <i className="fa fa-times" />
          </button>
        </div>
      );
    default:
      if (inCollection) {
        return (
          <div className="btn btn-success" onClick={() => setState("pick-kind")}>
            <i className="fa fa-check" />
            &nbsp; {detailView ? "Add additional entries to collection?" : "Add again?"}
          </div>
        );
      } else {
        return (
          <div className="btn btn-secondary" onClick={() => setState("pick-kind")}>
            Add to collection
          </div>
        );
      }
  }
};

const Loader = () => (
  <div className="loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);
