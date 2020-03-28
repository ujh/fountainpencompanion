import React, { useState, useEffect, useContext } from "react";
import Jsona from "jsona";

import { getRequest } from "src/fetch";
import { DisplayMicroCluster } from "./DisplayMicroCluster";
import { DisplayMacroClusters } from "./DisplayMacroClusters";
import { StateContext, DispatchContext } from "./App";
import {
  PREVIOUS,
  NEXT,
  REMOVE_MICRO_CLUSTER,
  LOADING,
  SET_MACRO_CLUSTERS
} from "./actions";

export const DisplayMicroClusters = () => {
  const { activeCluster, loadingMacroClusters } = useContext(StateContext);
  const dispatch = useContext(DispatchContext);
  const { prev, next } = useNavigation(dispatch);
  const macroClusters = loadMacroClusters(activeCluster.id, dispatch);
  const afterAssign = newClusterData => {
    dispatch({ type: REMOVE_MICRO_CLUSTER, payload: newClusterData });
  };
  return (
    <div className="app">
      <div className="nav" onClick={prev}>
        <i className="fa fa-angle-left"></i>
      </div>
      <div className="main">
        <DisplayMicroCluster data={activeCluster} afterCreate={afterAssign}>
          {macroClusters && (
            <DisplayMacroClusters
              data={macroClusters}
              microCluster={activeCluster}
              afterAssign={afterAssign}
              loading={loadingMacroClusters}
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

const loadMacroClusters = (id, dispatch) => {
  const [macroClusters, setMacroClusters] = useState([]);
  useEffect(() => {
    dispatch({ type: LOADING });
    let data = [];
    const formatter = new Jsona();
    function run(page = 1) {
      loadMacroClusterPage(page).then(json => {
        const next_page = json.meta.pagination.next_page;
        data = [...data, ...formatter.deserialize(json)];
        if (next_page) {
          run(next_page);
        } else {
          setMacroClusters(data);
          dispatch({ type: SET_MACRO_CLUSTERS, payload: data });
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
