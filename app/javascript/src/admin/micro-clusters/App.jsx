import React, { useEffect, useReducer, useContext } from "react";
import Select from "react-select";
import _ from "lodash";

import { Spinner } from "../components/Spinner";
import { DisplayMicroClusters } from "./DisplayMicroClusters";
import { reducer, initalState } from "../components/clustering/reducer";
import { UPDATE_SELECTED_BRANDS } from "../components/clustering/actions";
import { setInBrandSelector } from "../components/clustering/keyDownListener";
import { loadMacroClusters, loadMicroClusters } from "./loadClusters";

export const StateContext = React.createContext();
export const DispatchContext = React.createContext();

export const App = () => {
  const [state, dispatch] = useReducer(reducer, initalState);
  const { loadingMacroClusters, loadingMicroClusters } = state;
  useEffect(() => {
    loadMicroClusters(dispatch);
  }, []);
  useEffect(() => {
    loadMacroClusters(dispatch);
  }, []);
  useEffect(() => {
    if (
      loadingMicroClusters ||
      loadingMacroClusters ||
      state.microClusters.length > 0
    )
      return;
    const intervalId = setInterval(() => {
      loadMicroClusters(dispatch);
    }, 30 * 1000);
    return () => {
      clearInterval(intervalId);
    };
  }, [loadingMicroClusters, loadingMacroClusters, state.microClusters.length]);
  if (!loadingMicroClusters && !loadingMacroClusters) {
    return (
      <DispatchContext.Provider value={dispatch}>
        <StateContext.Provider value={state}>
          <div>
            <LoadingOverlay />
            <Summary />
            <BrandSelector />
            <DisplayMicroClusters />
          </div>
        </StateContext.Provider>
      </DispatchContext.Provider>
    );
  } else {
    return <Spinner text={`${state.loadingPercentage.toFixed(2)}%`} />;
  }
};

const LoadingOverlay = () => {
  const { updating } = useContext(StateContext);
  if (!updating) return null;
  const style = {
    position: "fixed",
    top: 0,
    left: 0,
    height: "100%",
    width: "100%",
    zIndex: 10,
    backgroundColor: "rgba(0,0,0,0.5)"
  };
  return <div style={style}></div>;
};

const Summary = () => {
  const { microClusters, selectedMicroClusters } = useContext(StateContext);
  return (
    <div className="summary">
      <b>Total:</b> {microClusters.length} <b>In Selection:</b>{" "}
      {selectedMicroClusters.length}
    </div>
  );
};

const BrandSelector = () => {
  const dispatch = useContext(DispatchContext);
  const { microClusters, selectedBrands } = useContext(StateContext);
  const values = _.countBy(microClusters.map((c) => c.simplified_brand_name));
  const options = _.sortBy(
    _.map(values, (value, key) => ({
      value: key,
      label: `${key} (${value})`
    })),
    "label"
  );
  return (
    <div className="mb-3">
      <Select
        options={options}
        onChange={(selected) => {
          dispatch({ type: UPDATE_SELECTED_BRANDS, payload: selected });
        }}
        isMulti
        value={selectedBrands}
        onFocus={() => {
          setInBrandSelector(true);
        }}
        onBlur={() => {
          setInBrandSelector(false);
        }}
      />
    </div>
  );
};
