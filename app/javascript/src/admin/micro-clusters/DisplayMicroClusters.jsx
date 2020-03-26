import React, { useState, useEffect, useContext } from "react";
import { getRequest } from "src/fetch";
import { DisplayMicroCluster } from "./DisplayMicroCluster";
import { DisplayMacroClusters } from "./DisplayMacroClusters";
import { StateContext, DispatchContext } from "./App";
import { PREVIOUS, NEXT, REMOVE_MICRO_CLUSTER } from "./actions";

export const DisplayMicroClusters = () => {
  const { selectedMicroClusters, index } = useContext(StateContext);
  const dispatch = useContext(DispatchContext);
  const { prev, next } = useNavigation(dispatch);
  const [loading, setLoading] = useState(false);
  const selectedMicroCluster = extractMicroClusterData(
    selectedMicroClusters,
    index
  );
  const macroClusters = loadMacroClusters(selectedMicroCluster.id, setLoading);
  const afterAssign = newClusterData => {
    dispatch({ type: REMOVE_MICRO_CLUSTER, payload: newClusterData });
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

const useNavigation = dispatch => {
  const next = () => dispatch({ type: NEXT });
  const prev = () => dispatch({ type: PREVIOUS });
  useEffect(() => {
    const listener = e => {
      if (e.keyCode == 39) next();
      if (e.keyCode == 37) prev();
    };
    document.addEventListener("keydown", listener);
    return () => {
      document.removeEventListener("keydown", listener);
    };
  }, []);
  return { prev, next };
};

const loadMacroClusters = (id, setLoading) => {
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
  }, [id]);
  return macroClusters;
};

const loadMacroClusterPage = page => {
  return getRequest(`/admins/macro_clusters.json?page=${page}`).then(response =>
    response.json()
  );
};
