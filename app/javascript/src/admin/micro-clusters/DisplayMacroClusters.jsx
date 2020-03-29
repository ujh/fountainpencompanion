import React, { useState, useContext, useEffect } from "react";
import _ from "lodash";
import levenshtein from "fast-levenshtein";
import ScrollIntoViewIfNeeded from "react-scroll-into-view-if-needed";

import { assignCluster } from "./assignCluster";
import { CollectedInksList } from "./CollectedInksList";
import { SearchLink } from "./SearchLink";
import { StateContext, DispatchContext } from "./App";
import {
  ASSIGN_TO_MACRO_CLUSTER,
  NEXT_MACRO_CLUSTER,
  PREVIOUS_MACRO_CLUSTER
} from "./actions";

export const DisplayMacroClusters = ({ afterAssign }) => {
  const dispatch = useContext(DispatchContext);
  useEffect(() => {
    const listener = ({ keyCode }) => {
      if (keyCode == 74) dispatch({ type: NEXT_MACRO_CLUSTER });
      if (keyCode == 75) dispatch({ type: PREVIOUS_MACRO_CLUSTER });
    };
    document.addEventListener("keydown", listener);
    return () => {
      document.removeEventListener("keydown", listener);
    };
  }, []);
  return <MacroClusterRows afterAssign={afterAssign} />;
};

const MacroClusterRows = ({ afterAssign }) => {
  const {
    macroClusters,
    activeCluster,
    selectedMacroClusterIndex
  } = useContext(StateContext);
  return _.sortBy(
    withDistance(macroClusters, activeCluster),
    "distance"
  ).map((macroCluster, index) => (
    <MacroClusterRow
      key={macroCluster.id}
      macroCluster={macroCluster}
      afterAssign={afterAssign}
      selected={index == selectedMacroClusterIndex}
    />
  ));
};

// This is the most expensive computation in this app. Group inks by name first
// and only compare between those that are really different.
const withDistance = (macroClusters, activeCluster) => {
  const activeGroupedInks = groupedInks(activeCluster.collected_inks);
  return macroClusters.map(c => ({
    ...c,
    distance: dist(
      groupedInks(c.micro_clusters.map(c => c.collected_inks).flat()),
      activeGroupedInks
    )
  }));
};

const dist = (macroClusterInks, microClusterInks) => {
  const calc1 = (c1, c2) =>
    levenshtein.get(c1.brand_name, c2.brand_name) +
    0.5 * levenshtein.get(c1.line_name, c2.line_name) +
    levenshtein.get(c1.ink_name, c2.ink_name);
  const calc2 = (c1, c2) =>
    levenshtein.get(
      [c1.brand_name, c1.line_name, c1.ink_name].join(""),
      [c2.brand_name, c2.line_name, c2.ink_name].join("")
    );
  const calc3 = (c1, c2) =>
    levenshtein.get(c1.brand_name, c2.brand_name) +
    levenshtein.get(c1.ink_name, c2.ink_name);
  let minDistance = Number.MAX_SAFE_INTEGER;
  macroClusterInks.forEach(ci1 => {
    microClusterInks.forEach(ci2 => {
      const dist = Math.min(
        ...[calc1(ci1, ci2), calc2(ci1, ci2), calc3(ci1, ci2)]
      );
      if (dist < minDistance) minDistance = dist;
    });
  });
  return minDistance;
};

const groupedInks = collectedInks =>
  _.values(
    _.mapValues(
      _.groupBy(collectedInks, ci =>
        ["brand_name", "line_name", "ink_name"].map(n => ci[n]).join(",")
      ),
      cis => cis[0]
    )
  );

const MacroClusterRow = ({ macroCluster, afterAssign, selected }) => {
  const { activeCluster, updating } = useContext(StateContext);
  const dispatch = useContext(DispatchContext);
  const [showInks, setShowInks] = useState(false);
  const onClick = () => setShowInks(!showInks);
  const assign = () => {
    assignCluster(activeCluster.id, macroCluster.id).then(microCluster => {
      dispatch({
        type: ASSIGN_TO_MACRO_CLUSTER,
        payload: microCluster
      });
      afterAssign(microCluster);
    });
  };
  useEffect(() => {
    if (!selected) return;

    const listener = ({ keyCode }) => {
      if (keyCode == 65) assign();
    };
    document.addEventListener("keydown", listener);
    return () => {
      document.removeEventListener("keydown", listener);
    };
  }, [macroCluster.id, selected]);
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
        <td
          style={{
            backgroundColor: macroCluster.color,
            width: "30px"
          }}
          onClick={onClick}
        ></td>
        <td>
          <SearchLink ci={macroCluster} />
        </td>
        <td>
          <input
            className="btn btn-default"
            type="submit"
            disabled={updating}
            value="Assign"
            onClick={assign}
          />
        </td>
      </tr>
      {(showInks || selected) && (
        <tr>
          <td colSpan="7">
            <table className="table macro-cluster-collected-inks">
              <tbody>
                <CollectedInksList
                  collectedInks={macroCluster.micro_clusters
                    .map(c => c.collected_inks)
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
