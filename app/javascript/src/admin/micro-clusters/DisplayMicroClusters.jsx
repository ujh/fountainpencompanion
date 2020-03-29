import React, { useState, useEffect, useContext } from "react";
import Jsona from "jsona";

import { getRequest } from "src/fetch";
import { DisplayMicroCluster } from "./DisplayMicroCluster";
import { DispatchContext } from "./App";
import {
  PREVIOUS,
  NEXT,
  REMOVE_MICRO_CLUSTER,
  UPDATE_MACRO_CLUSTER
} from "./actions";

export const DisplayMicroClusters = () => {
  const dispatch = useContext(DispatchContext);
  const { prev, next } = useNavigation(dispatch);
  const afterAssign = newClusterData => {
    dispatch({ type: REMOVE_MICRO_CLUSTER, payload: newClusterData });
    const id = newClusterData.macro_cluster.id;
    updateMacroCluster(id, dispatch);
  };
  return (
    <div className="app">
      <div className="nav" onClick={prev}>
        <i className="fa fa-angle-left"></i>
      </div>
      <div className="main">
        <DisplayMicroCluster afterCreate={afterAssign}></DisplayMicroCluster>
      </div>
      <div className="nav" onClick={next}>
        <i className="fa fa-angle-right"></i>
      </div>
    </div>
  );
};

const updateMacroCluster = (id, dispatch) => {
  setTimeout(() => {
    getRequest(`/admins/macro_clusters/${id}.json`)
      .then(response => response.json())
      .then(json => {
        const formatter = new Jsona();
        return formatter.deserialize(json);
      })
      .then(macroCluster =>
        dispatch({ type: UPDATE_MACRO_CLUSTER, payload: macroCluster })
      );
  }, 500);
};

const useNavigation = dispatch => {
  const next = () => dispatch({ type: NEXT });
  const prev = () => dispatch({ type: PREVIOUS });
  useEffect(() => {
    const listener = e => {
      if (window.inBrandSelector) return;

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
