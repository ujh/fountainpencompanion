import React, { useEffect, useReducer, useContext } from "react";
import Select from "react-select";
import _ from "lodash";
import Jsona from "jsona";

import { getRequest } from "src/fetch";
import { Spinner } from "./Spinner";
import { DisplayMicroClusters } from "./DisplayMicroClusters";
import { reducer, initalState } from "./reducer";
import {
  SET_MACRO_CLUSTERS,
  SET_MICRO_CLUSTERS,
  UPDATE_SELECTED_BRANDS
} from "./actions";

export const StateContext = React.createContext();
export const DispatchContext = React.createContext();

export const App = () => {
  const [state, dispatch] = useReducer(reducer, initalState);
  const { loadingMacroClusters, loadingMicroClusters } = state;
  loadMicroClusters(dispatch);
  loadMacroClusters(dispatch);
  if (!loadingMicroClusters && !loadingMacroClusters) {
    return (
      <DispatchContext.Provider value={dispatch}>
        <StateContext.Provider value={state}>
          <div>
            <Summary />
            <BrandSelector />
            <DisplayMicroClusters />
          </div>
        </StateContext.Provider>
      </DispatchContext.Provider>
    );
  } else {
    return <Spinner />;
  }
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
  const values = _.countBy(microClusters.map(c => c.simplified_brand_name));
  const options = _.map(values, (value, key) => ({
    value: key,
    label: `${key} (${value})`
  }));
  return (
    <div>
      <Select
        options={options}
        onChange={selected => {
          dispatch({ type: UPDATE_SELECTED_BRANDS, payload: selected });
        }}
        isMulti
        value={selectedBrands}
        onFocus={() => {
          window.inBrandSelector = true;
        }}
        onBlur={() => {
          window.inBrandSelector = false;
        }}
      />
    </div>
  );
};
const loadMicroClusters = dispatch => {
  useEffect(() => {
    const formatter = new Jsona();
    let data = [];
    function run(page = 1) {
      loadMicroClusterPage(page).then(json => {
        const next_page = json.meta.pagination.next_page;
        data = [...data, ...formatter.deserialize(json)];
        if (next_page) {
          run(next_page);
        } else {
          dispatch({ type: SET_MICRO_CLUSTERS, payload: data });
        }
      });
    }
    run();
  }, []);
};

const loadMicroClusterPage = page => {
  return getRequest(
    `/admins/micro_clusters.json?unassigned=true&page=${page}`
  ).then(response => response.json());
};

const loadMacroClusters = dispatch => {
  useEffect(() => {
    let data = [];
    const formatter = new Jsona();
    function run(page = 1) {
      loadMacroClusterPage(page).then(json => {
        const next_page = json.meta.pagination.next_page;
        data = [...data, ...formatter.deserialize(json)];
        if (next_page) {
          run(next_page);
        } else {
          dispatch({ type: SET_MACRO_CLUSTERS, payload: data });
        }
      });
    }
    run();
  }, []);
};

const loadMacroClusterPage = page => {
  return getRequest(`/admins/macro_clusters.json?page=${page}`).then(response =>
    response.json()
  );
};
