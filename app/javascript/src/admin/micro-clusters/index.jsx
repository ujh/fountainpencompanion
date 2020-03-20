import React, { useState, useEffect, useMemo } from "react";
import ReactDOM from "react-dom";

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

const DisplayMicroClusters = ({ data }) => {
  const index = 0;
  const selectedClusterData = useMemo(
    () => extractMicroClusterData(data, index),
    [index]
  );
  return (
    <div className="app">
      <div className="nav">
        <i className="fa fa-angle-left"></i>
      </div>
      <div className="main">
        <DisplayMicroCluster data={selectedClusterData} />
      </div>
      <div className="nav">
        <i className="fa fa-angle-right"></i>
      </div>
    </div>
  );
};

const DisplayMicroCluster = ({ data }) => {
  console.log(data);
  return (
    <div>
      <table className="table table-striped">
        <thead>
          <tr>
            <th>{data.attributes.simplified_brand_name}</th>
            <th>{data.attributes.simplified_line_name}</th>
            <th>{data.attributes.simplified_ink_name}</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {data.collected_inks.map(ci => (
            <tr key={ci.id}>
              <td>{ci.attributes.brand_name}</td>
              <td>{ci.attributes.line_name}</td>
              <td>{ci.attributes.ink_name}</td>
              <td>{ci.attributes.maker}</td>
            </tr>
          ))}
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
