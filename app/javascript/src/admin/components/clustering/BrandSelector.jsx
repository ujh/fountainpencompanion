import React, { useContext } from "react";
import Select from "react-select";
import _ from "lodash";

import { DispatchContext, StateContext } from "./App";
import { UPDATE_SELECTED_BRANDS } from "./actions";
import { setInBrandSelector } from "./keyDownListener";

export const BrandSelector = ({ field }) => {
  const dispatch = useContext(DispatchContext);
  const { microClusters, selectedBrands } = useContext(StateContext);
  const values = _.countBy(microClusters.map((c) => c[field]));
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
