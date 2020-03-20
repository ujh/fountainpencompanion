import React, { useState, useEffect, useMemo } from "react";
import { DisplayMicroCluster } from "./DisplayMicroCluster";

export const DisplayMicroClusters = ({ data }) => {
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
