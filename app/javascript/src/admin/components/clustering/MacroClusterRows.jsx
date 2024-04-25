import _ from "lodash";
import { matchSorter } from "match-sorter";
import React, { useContext, useEffect, useState } from "react";
import { MacroClusterRow } from "./MacroClusterRow";
import { setInBrandSelector } from "./keyDownListener";
import { StateContext } from "./App";

export const MacroClusterRows = ({
  afterAssign,
  assignCluster,
  withDistance,
  extraColumn,
  fields
}) => {
  const {
    macroClusters,
    activeCluster,
    selectedMacroClusterIndex,
    updateCounter
  } = useContext(StateContext);
  const [clustersWithDistance, setClustersWithDistance] = useState([]);
  const [computing, setComputing] = useState(true);
  const [search, setSearch] = useState("");
  useEffect(() => {
    setComputing(true);
    setTimeout(() => {
      setClustersWithDistance(
        _.sortBy(withDistance(macroClusters, activeCluster), "distance")
      );
      setComputing(false);
    }, 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeCluster.id, updateCounter]);
  // Reset search for each new cluster
  useEffect(() => {
    setSearch("");
  }, [activeCluster.id]);
  if (computing)
    return (
      <tr className="loading">
        <td colSpan="8">Computing ...</td>
      </tr>
    );
  const clustersToRender = search
    ? matchSorter(clustersWithDistance, search, {
        keys: fields
      })
    : clustersWithDistance;
  const rows = clustersToRender
    .slice(0, 100) // Shaves of > 1s when rerendering
    .map((macroCluster, index) => (
      <MacroClusterRow
        key={macroCluster.id}
        macroCluster={macroCluster}
        afterAssign={afterAssign}
        assignCluster={assignCluster}
        selected={index == selectedMacroClusterIndex}
        fields={fields}
        extraColumn={extraColumn}
      />
    ));
  const inputRow = (
    <tr key="search-box">
      <td colSpan="8">
        <input
          className="form-control"
          aria-label="Filter"
          placeholder="Filter existing"
          type="text"
          value={search}
          onChange={(e) => {
            e.stopPropagation();
            setSearch(e.target.value);
          }}
          onFocus={() => setInBrandSelector(true)}
          onBlur={() => {
            setInBrandSelector(false);
          }}
        ></input>
      </td>
    </tr>
  );
  return [inputRow, ...rows];
};
