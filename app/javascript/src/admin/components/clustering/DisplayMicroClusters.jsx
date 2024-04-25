import React, { useContext, useEffect, useCallback } from "react";

import { DispatchContext, StateContext } from "../../micro-clusters/GenericApp";
import { DisplayMicroCluster } from "./DisplayMicroCluster";
import { NEXT, PREVIOUS, REMOVE_MICRO_CLUSTER } from "./actions";
import { keyDownListener } from "./keyDownListener";

export const DisplayMicroClusters = ({
  macroClusterUpdater,
  assignCluster,
  fields,
  withDistance,
  ignoreCluster,
  extraColumn,
  createMacroClusterAndAssign
}) => {
  const dispatch = useContext(DispatchContext);
  const { activeCluster } = useContext(StateContext);
  const { prev, next } = useNavigation(dispatch);
  const afterAssign = (newClusterData) => {
    dispatch({ type: REMOVE_MICRO_CLUSTER, payload: newClusterData });
    const id = newClusterData.macro_cluster.id;
    macroClusterUpdater(id, dispatch);
  };
  if (activeCluster) {
    return (
      <div className="app">
        <div className="nav" onClick={prev}>
          <i className="fa fa-angle-left"></i>
        </div>
        <div className="main">
          <DisplayMicroCluster
            afterCreate={afterAssign}
            assignCluster={assignCluster}
            fields={fields}
            withDistance={withDistance}
            ignoreCluster={ignoreCluster}
            extraColumn={extraColumn}
            createMacroClusterAndAssign={createMacroClusterAndAssign}
          ></DisplayMicroCluster>
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
