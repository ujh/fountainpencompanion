import React, { useEffect, useReducer } from "react";

import { Spinner } from "../Spinner";
import { BrandSelector } from "./BrandSelector";
import { LoadingOverlay } from "./LoadingOverlay";
import { Summary } from "./Summary";
import { initalState, reducer } from "./reducer";
import { DisplayMicroClusters } from "./DisplayMicroClusters";

export const StateContext = React.createContext();
export const DispatchContext = React.createContext();

export const App = ({
  brandSelectorField,
  microClusterLoader,
  macroClusterLoader,
  macroClusterUpdater,
  assignCluster,
  createMacroClusterAndAssign,
  extraColumn,
  ignoreCluster,
  withDistance
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
            <DisplayMicroClusters
              macroClusterUpdater={macroClusterUpdater}
              assignCluster={assignCluster}
              fields={["brand_name", "line_name", "ink_name"]}
              withDistance={withDistance}
              ignoreCluster={ignoreCluster}
              extraColumn={extraColumn}
              createMacroClusterAndAssign={createMacroClusterAndAssign}
            />
          </div>
        </StateContext.Provider>
      </DispatchContext.Provider>
    );
  } else {
    return <Spinner text={`${state.loadingPercentage.toFixed(2)}%`} />;
  }
};
