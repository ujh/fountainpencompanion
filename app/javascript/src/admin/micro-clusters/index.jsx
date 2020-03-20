import React, { useState, useEffect, useMemo } from "react";
import ReactDOM from "react-dom";
import _ from "lodash";

import { getRequest } from "src/fetch";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("micro-clusters-app");
  ReactDOM.render(<App />, el);
});

const loadMicroClusters = () => {
  const [microClusters, setMicroClusters] = useState(null);
  useEffect(() => {
    getRequest("/admins/micro_clusters.json")
      .then(response => response.json())
      .then(json => {
        setMicroClusters(json);
      });
  }, []);
  return microClusters;
};

const App = () => {
  const microClusters = loadMicroClusters();
  if (microClusters) {
    return <DisplayMicroClusters data={microClusters} />;
  } else {
    return <Spinner />;
  }
};

const extractMicroClusterData = (data, index) => {
  const cluster = data.data[index];
  cluster.collected_inks = cluster.relationships.collected_inks.data.map(rc =>
    data.included.find(i => i.id == rc.id && i.type == rc.type)
  );
  return cluster;
};

const useNavigation = max => {
  const [index, setIndex] = useState(0);
  const prev = () => {
    if (index > 0) setIndex(index - 1);
  };
  const next = () => {
    if (index < max) setIndex(index + 1);
  };
  useEffect(() => {
    const listener = e => {
      if (e.keyCode == 39) next();
      if (e.keyCode == 37) prev();
    };
    document.addEventListener("keydown", listener);
    return () => {
      document.removeEventListener("keydown", listener);
    };
  }, [index]);
  return { index, prev, next };
};

const DisplayMicroClusters = ({ data }) => {
  const { index, prev, next } = useNavigation(data.data.length);
  const selectedClusterData = useMemo(
    () => extractMicroClusterData(data, index),
    [index]
  );
  return (
    <div className="app">
      <div className="nav" onClick={prev}>
        <i className="fa fa-angle-left"></i>
      </div>
      <div className="main">
        <DisplayMicroCluster data={selectedClusterData} />
      </div>
      <div className="nav" onClick={next}>
        <i className="fa fa-angle-right"></i>
      </div>
    </div>
  );
};

const DisplayMicroCluster = ({ data }) => {
  const grouped = _.groupBy(data.collected_inks, ci =>
    ["brand_name", "line_name", "ink_name"].map(n => ci.attributes[n]).join("")
  );
  return (
    <div>
      <table className="table table-striped">
        <thead>
          <tr>
            <th></th>
            <th>{data.attributes.simplified_brand_name}</th>
            <th>{data.attributes.simplified_line_name}</th>
            <th>{data.attributes.simplified_ink_name}</th>
            <th></th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {_.values(grouped).map(cis => {
            const ci = cis[0];
            const count = cis.length;
            return (
              <tr key={ci.id}>
                <td>{count}</td>
                <td>{ci.attributes.brand_name}</td>
                <td>{ci.attributes.line_name}</td>
                <td>{ci.attributes.ink_name}</td>
                <td>{ci.attributes.maker}</td>
                <td
                  style={{
                    backgroundColor: ci.attributes.color,
                    width: "30px"
                  }}
                ></td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};

const Spinner = () => (
  <div className="loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);
