import React, { useEffect, useContext } from "react";
import Jsona from "jsona";

import { getRequest } from "../../fetch";
import { DisplayMicroCluster } from "./DisplayMicroCluster";
import { DispatchContext, StateContext } from "./App";
import { groupedInks } from "./groupedInks";
import {
  PREVIOUS,
  NEXT,
  REMOVE_MICRO_CLUSTER,
  UPDATE_MACRO_CLUSTER
} from "../components/clustering/actions";
import { keyDownListener } from "../components/clustering/keyDownListener";
import { useCallback } from "react";

export const DisplayMicroClusters = () => {
  const dispatch = useContext(DispatchContext);
  const { activeCluster } = useContext(StateContext);
  const { prev, next } = useNavigation(dispatch);
  const afterAssign = (newClusterData) => {
    dispatch({ type: REMOVE_MICRO_CLUSTER, payload: newClusterData });
    const id = newClusterData.macro_cluster.id;
    updateMacroCluster(id, dispatch);
  };
  if (activeCluster) {
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
  } else {
    return <div>No clusters to assign.</div>;
  }
};

const updateMacroCluster = (id, dispatch) => {
  setTimeout(() => {
    getRequest(`/admins/macro_clusters/${id}.json`)
      .then((response) => response.json())
      .then((json) => {
        const formatter = new Jsona();
        const macroCluster = formatter.deserialize(json);
        const grouped_entries = groupedInks(
          macroCluster.micro_clusters.map((c) => c.collected_inks).flat()
        );
        return { ...macroCluster, grouped_entries };
      })
      .then((macroCluster) =>
        dispatch({ type: UPDATE_MACRO_CLUSTER, payload: macroCluster })
      );
  }, 500);
};

const useNavigation = (dispatch) => {
  const next = useCallback(() => dispatch({ type: NEXT }), [dispatch]);
  const prev = useCallback(() => dispatch({ type: PREVIOUS }), [dispatch]);
  useEffect(() => {
    return keyDownListener((e) => {
      if (e.keyCode == 39) next();
      if (e.keyCode == 37) prev();
    });
  }, [next, prev]);
  return { prev, next };
};
