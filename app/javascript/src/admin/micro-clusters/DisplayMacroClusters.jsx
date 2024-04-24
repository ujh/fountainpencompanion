import React, { useState, useContext, useEffect } from "react";
import _ from "lodash";
import levenshtein from "fast-levenshtein";
import ScrollIntoViewIfNeeded from "react-scroll-into-view-if-needed";
import { matchSorter } from "match-sorter";

import { assignCluster } from "./assignCluster";
import { CollectedInksList } from "./CollectedInksList";
import { SearchLink } from "./SearchLink";
import { StateContext, DispatchContext } from "./App";
import {
  ASSIGN_TO_MACRO_CLUSTER,
  NEXT_MACRO_CLUSTER,
  PREVIOUS_MACRO_CLUSTER,
  UPDATING
} from "../components/clustering/actions";
import {
  keyDownListener,
  setInBrandSelector
} from "../components/clustering/keyDownListener";
import { useCallback } from "react";

export const DisplayMacroClusters = ({ afterAssign }) => {
  const dispatch = useContext(DispatchContext);
  useEffect(() => {
    return keyDownListener(({ keyCode }) => {
      if (keyCode == 74) dispatch({ type: NEXT_MACRO_CLUSTER });
      if (keyCode == 75) dispatch({ type: PREVIOUS_MACRO_CLUSTER });
    });
  }, [dispatch]);
  return <MacroClusterRows afterAssign={afterAssign} />;
};

const MacroClusterRows = ({ afterAssign }) => {
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
        keys: ["brand_name", "line_name", "ink_name"]
      })
    : clustersWithDistance;
  const rows = clustersToRender
    .slice(0, 100) // Shaves of > 1s when rerendering
    .map((macroCluster, index) => (
      <MacroClusterRow
        key={macroCluster.id}
        macroCluster={macroCluster}
        afterAssign={afterAssign}
        selected={index == selectedMacroClusterIndex}
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

// This is the most expensive computation in this app. Group inks by name first
// and only compare between those that are really different.
const withDistance = (macroClusters, activeCluster) => {
  const activeGroupedInks = activeCluster.grouped_entries;
  return macroClusters.map((c) => {
    const macroClusterInks = c.grouped_entries.concat(c);
    return {
      ...c,
      distance: dist(macroClusterInks, activeGroupedInks)
    };
  });
};

const dist = (macroClusterInks, microClusterInks) => {
  const calc1 = (c1, c2) =>
    minLev(c1.brand_name, c2.brand_name) +
    0.5 * minLev(c1.line_name, c2.line_name) +
    minLev(c1.ink_name, c2.ink_name);
  const calc2 = (c1, c2) =>
    minLev(
      [c1.brand_name, c1.line_name, c1.ink_name].join(""),
      [c2.brand_name, c2.line_name, c2.ink_name].join("")
    );
  const calc3 = (c1, c2) =>
    minLev(c1.brand_name, c2.brand_name) + minLev(c1.ink_name, c2.ink_name);
  const calc4 = (c1, c2) => {
    if (!c1.line_name && !c2.line_name) return Number.MAX_SAFE_INTEGER;
    return Math.min(
      minLev(
        [c1.brand_name, c1.ink_name].join(""),
        [c2.line_name, c2.ink_name].join("")
      ),
      minLev(
        [c2.brand_name, c2.ink_name].join(""),
        [c1.line_name, c1.ink_name].join("")
      )
    );
  };

  let minDistance = Number.MAX_SAFE_INTEGER;
  macroClusterInks.forEach((ci1) => {
    microClusterInks.forEach((ci2) => {
      const dist = Math.min(
        ...[calc1(ci1, ci2), calc2(ci1, ci2), calc3(ci1, ci2), calc4(ci1, ci2)]
      );
      if (dist < minDistance) minDistance = dist;
    });
  });
  return minDistance;
};

const minLev = (str1, str2) => {
  return Math.min(
    levenshtein.get(str1, str2),
    levenshtein.get(stripped(str1), stripped(str2))
  );
};

const stripped = (str) => {
  return str
    .replace(/-/i, "")
    .replace(/(\([^)]*\))/i, "")
    .replace(/\s+/i, "");
};

const MacroClusterRow = ({ macroCluster, afterAssign, selected }) => {
  const { activeCluster, updating } = useContext(StateContext);
  const dispatch = useContext(DispatchContext);
  const [showInks, setShowInks] = useState(false);
  const onClick = () => setShowInks(!showInks);
  const assign = useCallback(() => {
    dispatch({ type: UPDATING });
    setTimeout(() => {
      assignCluster(activeCluster.id, macroCluster.id).then((microCluster) => {
        dispatch({
          type: ASSIGN_TO_MACRO_CLUSTER,
          payload: microCluster
        });
        afterAssign(microCluster);
      });
    }, 10);
  }, [activeCluster.id, afterAssign, dispatch, macroCluster.id]);
  useEffect(() => {
    if (!selected) return;

    return keyDownListener(({ keyCode }) => {
      if (keyCode == 65) assign();
    });
  }, [macroCluster.id, activeCluster.id, selected, assign]);
  return (
    <>
      <tr className={selected ? "selected" : ""}>
        <td className="distance" onClick={onClick}>
          <ScrollIntoViewIfNeeded active={selected}>
            {macroCluster.distance}
          </ScrollIntoViewIfNeeded>
        </td>
        <td onClick={onClick}>{macroCluster.brand_name}</td>
        <td onClick={onClick}>{macroCluster.line_name}</td>
        <td onClick={onClick}>{macroCluster.ink_name}</td>
        <td onClick={onClick}></td>
        <td onClick={onClick}>
          <div
            style={{
              backgroundColor: macroCluster.color,
              height: "45px",
              width: "45px"
            }}
          />
        </td>
        <td>
          <SearchLink ci={macroCluster} />
        </td>
        <td>
          <button
            className="btn btn-secondary"
            type="submit"
            disabled={updating}
            onClick={assign}
          >
            Assign
          </button>
        </td>
      </tr>
      {(showInks || selected) && (
        <tr>
          <td colSpan="7">
            <table className="table macro-cluster-collected-inks">
              <tbody>
                <CollectedInksList
                  collectedInks={macroCluster.micro_clusters
                    .map((c) => c.entries)
                    .flat()}
                />
              </tbody>
            </table>
          </td>
        </tr>
      )}
    </>
  );
};
