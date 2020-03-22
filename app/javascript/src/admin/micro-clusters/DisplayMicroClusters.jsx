import React, { useState, useEffect, useMemo } from "react";
import { getRequest } from "src/fetch";
import { DisplayMicroCluster } from "./DisplayMicroCluster";
import { DisplayMacroClusters } from "./DisplayMacroClusters";
import { Spinner } from "./Spinner";

export const DisplayMicroClusters = ({ microClusters }) => {
  const { index, prev, next, direction } = useNavigation(microClusters);
  const [loading, setLoading] = useState(false);
  const selectedMicroCluster = extractMicroClusterData(microClusters, index);
  const macroClusters = loadMacroClusters(index, setLoading);
  const afterAssign = newClusterData => {
    microClusters.data[index] = newClusterData;
    next();
  };
  if (microClusters.data[index].relationships.macro_cluster.data) {
    direction == "next" ? next() : prev();
  }
  return (
    <div className="app">
      <div className="nav" onClick={prev}>
        <i className="fa fa-angle-left"></i>
      </div>
      <div className="main">
        <DisplayMicroCluster
          data={selectedMicroCluster}
          afterCreate={afterAssign}
          loading={loading}
          setLoading={setLoading}
        >
          {macroClusters && (
            <DisplayMacroClusters
              data={macroClusters}
              microCluster={selectedMicroCluster}
              afterAssign={afterAssign}
              loading={loading}
            />
          )}
        </DisplayMicroCluster>
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

const useNavigation = microClusters => {
  const [index, setIndex] = useState(0);
  const [max, setMax] = useState(microClusters.data.length);
  useEffect(() => {
    setMax(microClusters.data.length);
  }, [microClusters]);
  const [direction, setDirection] = useState("next");
  const prev = () => {
    setDirection("prev");
    if (index > 0) setIndex(index - 1);
    if (index == 0) setIndex(max - 1);
  };
  const next = () => {
    setDirection("next");
    if (index < max - 1) setIndex(index + 1);
    if (index == max - 1) setIndex(0);
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
  return { index, prev, next, direction };
};

const loadMacroClusters = (index, setLoading) => {
  const [macroClusters, setMacroClusters] = useState({
    data: [],
    included: []
  });
  useEffect(() => {
    setLoading(true);
    setMacroClusters({ ...macroClusters });
    const data = { data: [], included: [] };
    function run(page = 1) {
      loadMacroClusterPage(page).then(json => {
        const next_page = json.meta.pagination.next_page;
        data.data = [...data.data, ...json.data];
        data.included = [...data.included, ...json.included];
        if (next_page) {
          run(next_page);
        } else {
          setMacroClusters(data);
          setLoading(false);
        }
      });
    }
    run();
  }, [index]);
  return macroClusters;
};

const loadMacroClusterPage = page => {
  return getRequest(`/admins/macro_clusters.json?page=${page}`).then(response =>
    response.json()
  );
};
