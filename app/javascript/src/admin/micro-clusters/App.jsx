import React, { useEffect, useReducer, useContext } from "react";
import Select from "react-select";
import _ from "lodash";
import Jsona from "jsona";
import queue from "queue";

import { getRequest } from "src/fetch";
import { Spinner } from "./Spinner";
import { DisplayMicroClusters } from "./DisplayMicroClusters";
import { reducer, initalState } from "./reducer";
import {
  SET_MACRO_CLUSTERS,
  SET_MICRO_CLUSTERS,
  UPDATE_SELECTED_BRANDS,
} from "./actions";
import { setInBrandSelector } from "./keyDownListener";

export const StateContext = React.createContext();
export const DispatchContext = React.createContext();

export const App = () => {
  const [state, dispatch] = useReducer(reducer, initalState);
  const { loadingMacroClusters, loadingMicroClusters } = state;
  useEffect(() => {
    loadMicroClusters(dispatch);
  }, []);
  loadMacroClusters(dispatch);
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
    return <Spinner />;
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
    backgroundColor: "rgba(0,0,0,0.5)",
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
      label: `${key} (${value})`,
    })),
    "label"
  );
  return (
    <div>
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
const loadMicroClusters = (dispatch) => {
  const formatter = new Jsona();
  let data = [];
  function run(page = 1) {
    loadMicroClusterPage(page).then((json) => {
      const next_page = json.meta.pagination.next_page;
      // Remove clusters without collected inks
      // Group collected inks
      const pageData = formatter
        .deserialize(json)
        .filter((c) => c.collected_inks.length > 0)
        .map((c) => {
          const grouped_collected_inks = groupedInks(c.collected_inks);
          return { ...c, grouped_collected_inks };
        });
      data = [...data, ...pageData];
      if (next_page) {
        run(next_page);
      } else {
        dispatch({ type: SET_MICRO_CLUSTERS, payload: data });
      }
    });
  }
  run();
};

const loadMicroClusterPage = (page) => {
  return getRequest(
    `/admins/micro_clusters.json?unassigned=true&without_ignored=true&page=${page}`
  ).then((response) => response.json());
};

const loadMacroClusters = (dispatch) => {
  useEffect(() => {
    async function fetchData() {
      let data = [];
      const {
        meta: {
          pagination: { total_pages },
        },
      } = await loadMacroClusterPage(1);
      function processPage(page = 1, cb) {
        loadMacroClusterPage(page).then((json) => {
          const pageData = json.data.map((c) => {
            const grouped_collected_inks = groupedInks(
              c.micro_clusters.map((c) => c.collected_inks).flat()
            );
            return { ...c, grouped_collected_inks };
          });
          data = [...data, ...pageData];
          cb();
        });
      }
      const q = queue({ concurrency: 2 });
      for (let i = 1; i <= total_pages; i++) {
        q.push((cb) => {
          processPage(i, cb);
        });
      }
      q.start(() => {
        dispatch({ type: SET_MACRO_CLUSTERS, payload: data });
      });
    }
    fetchData();
  }, []);
};

const loadMacroClusterPage = (page) => {
  return getRequest(
    `/admins/macro_clusters.json?page=${page}`
  ).then((response) => response.json());
};

export const groupedInks = (collectedInks) =>
  _.values(
    _.mapValues(
      _.groupBy(collectedInks, (ci) =>
        ["brand_name", "line_name", "ink_name"].map((n) => ci[n]).join(",")
      ),
      (cis) => cis[0]
    )
  );
