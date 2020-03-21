import React, { useState, useEffect, useMemo } from "react";
import { getRequest } from "src/fetch";
import { DisplayMicroCluster } from "./DisplayMicroCluster";
import { DisplayMacroClusters } from "./DisplayMacroClusters";
import { Spinner } from "./Spinner";

export const DisplayMicroClusters = ({ microClusters }) => {
  const { index, prev, next } = useNavigation(microClusters.data.length);
  const selectedMicroCluster = extractMicroClusterData(microClusters, index);
  const macroClusters = loadMacroClusters(index);
  const afterAssign = newClusterData => {
    microClusters.data[index] = newClusterData;
    next();
  };
  return (
    <div className="app">
      <div className="nav" onClick={prev}>
        <i className="fa fa-angle-left"></i>
      </div>
      <div className="main">
        <DisplayMicroCluster
          data={selectedMicroCluster}
          afterCreate={afterAssign}
        >
          {macroClusters && (
            <DisplayMacroClusters
              data={macroClusters}
              microCluster={selectedMicroCluster}
              afterAssign={afterAssign}
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

const useNavigation = max => {
  const [index, setIndex] = useState(Math.floor(Math.random() * max));
  const prev = () => {
    if (index > 0) setIndex(index - 1);
    if (index == 0) setIndex(max - 1);
  };
  const next = () => {
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
  return { index, prev, next };
};

const loadMacroClusters = index => {
  const [macroClusters, setMacroClusters] = useState(null);
  useEffect(() => {
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
