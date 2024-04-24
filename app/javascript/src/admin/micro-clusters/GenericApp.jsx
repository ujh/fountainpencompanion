import React, { useEffect, useReducer } from "react";

import { Spinner } from "../components/Spinner";
import { DisplayMicroClusters } from "./DisplayMicroClusters";
import { reducer, initalState } from "../components/clustering/reducer";
import { Summary } from "../components/clustering/Summary";
import { LoadingOverlay } from "../components/clustering/LoadingOverlay";
import { BrandSelector } from "../components/clustering/BrandSelector";

export const StateContext = React.createContext();
export const DispatchContext = React.createContext();

export const GenericApp = ({
  brandSelectorField,
  microClusterLoader,
  macroClusterLoader,
  macroClusterUpdater,
  assignCluster
}) => {
  const [state, dispatch] = useReducer(reducer, initalState);
  const { loadingMacroClusters, loadingMicroClusters } = state;
  useEffect(() => {
    microClusterLoader(dispatch);
  }, [microClusterLoader]);
  useEffect(() => {
    macroClusterLoader(dispatch);
  }, [macroClusterLoader]);
  useEffect(() => {
    if (
      loadingMicroClusters ||
      loadingMacroClusters ||
      state.microClusters.length > 0
    )
      return;
    const intervalId = setInterval(() => {
      microClusterLoader(dispatch);
    }, 30 * 1000);
    return () => {
      clearInterval(intervalId);
    };
  }, [
    loadingMicroClusters,
    loadingMacroClusters,
    state.microClusters.length,
    microClusterLoader
  ]);
  if (!loadingMicroClusters && !loadingMacroClusters) {
    return (
      <DispatchContext.Provider value={dispatch}>
        <StateContext.Provider value={state}>
          <div>
            <LoadingOverlay />
            <Summary />
            <BrandSelector field={brandSelectorField} />
            {/*** TODO:  DisplayMicroClusters is not yet generic ***/}
            <DisplayMicroClusters
              macroClusterUpdater={macroClusterUpdater}
              assignCluster={assignCluster}
            />
            {/*** TODO:  DisplayMicroClusters is not yet generic ***/}
          </div>
        </StateContext.Provider>
      </DispatchContext.Provider>
    );
  } else {
    return <Spinner text={`${state.loadingPercentage.toFixed(2)}%`} />;
  }
};
