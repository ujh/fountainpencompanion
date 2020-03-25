import React, { useState, useEffect, useReducer, useContext } from "react";
import Select from "react-select";
import _ from "lodash";
import { getRequest } from "src/fetch";
import { Spinner } from "./Spinner";
import { DisplayMicroClusters } from "./DisplayMicroClusters";
import { reducer, initalState } from "./reducer";
import { UPDATE_SELECTED_BRANDS } from "./actions";

export const StateContext = React.createContext();
export const DispatchContext = React.createContext();

export const App = () => {
  const [state, dispatch] = useReducer(reducer, initalState);
  const microClusters = loadMicroClusters();
  const [selectedMicroClusters, setSelectedMicroClusters] = useState(
    microClusters
  );
  useEffect(() => {
    if (!microClusters) return;
    if (state.selectedBrands.length) {
      setSelectedMicroClusters({
        included: microClusters.included,
        data: microClusters.data.filter(c =>
          state.selectedBrands
            .map(s => s.value)
            .includes(c.attributes.simplified_brand_name)
        )
      });
    } else {
      setSelectedMicroClusters(microClusters);
    }
  }, [state.selectedBrands, microClusters]);
  if (selectedMicroClusters) {
    return (
      <DispatchContext.Provider value={dispatch}>
        <StateContext.Provider value={state}>
          <div>
            <BrandSelector microClusters={microClusters} />
            <DisplayMicroClusters
              microClusters={selectedMicroClusters}
              onDone={() => {
                dispatch({ type: UPDATE_SELECTED_BRANDS, payload: [] });
              }}
            />
          </div>
        </StateContext.Provider>
      </DispatchContext.Provider>
    );
  } else {
    return <Spinner />;
  }
};

const BrandSelector = ({ microClusters }) => {
  const dispatch = useContext(DispatchContext);
  const state = useContext(StateContext);
  const values = _.countBy(
    microClusters.data.map(c => c.attributes.simplified_brand_name)
  );
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
        value={state.selectedBrands}
      />
    </div>
  );
};
const loadMicroClusters = () => {
  const [microClusters, setMicroClusters] = useState(null);
  useEffect(() => {
    const data = { data: [], included: [] };
    function run(page = 1) {
      loadMicroClusterPage(page).then(json => {
        const next_page = json.meta.pagination.next_page;
        data.data = [...data.data, ...json.data];
        data.included = [...data.included, ...json.included];
        if (next_page) {
          run(next_page);
        } else {
          setMicroClusters(data);
        }
      });
    }
    run();
  }, []);
  return microClusters;
};

const loadMicroClusterPage = page => {
  return getRequest(
    `/admins/micro_clusters.json?unassigned=true&page=${page}`
  ).then(response => response.json());
};
