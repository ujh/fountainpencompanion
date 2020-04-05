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
  PREVIOUS_MACRO_CLUSTER,
  UPDATING,
} from "./actions";
import { keyDownListener } from "./keyDownListener";

export const DisplayMacroClusters = ({ afterAssign }) => {
  const dispatch = useContext(DispatchContext);
  useEffect(() => {
    return keyDownListener(({ keyCode }) => {
      if (keyCode == 74) dispatch({ type: NEXT_MACRO_CLUSTER });
      if (keyCode == 75) dispatch({ type: PREVIOUS_MACRO_CLUSTER });
    });
  }, []);
  return <MacroClusterRows afterAssign={afterAssign} />;
};

const MacroClusterRows = ({ afterAssign }) => {
  const {
    macroClusters,
    activeCluster,
    selectedMacroClusterIndex,
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
  const activeGroupedInks = activeCluster.grouped_collected_inks;
  return macroClusters.map((c) => ({
    ...c,
    distance: dist(c.grouped_collected_inks, activeGroupedInks),
  }));
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
  const assign = () => {
    dispatch({ type: UPDATING });
    assignCluster(activeCluster.id, macroCluster.id).then((microCluster) => {
      dispatch({
        type: ASSIGN_TO_MACRO_CLUSTER,
        payload: microCluster,
      });
      afterAssign(microCluster);
    });
  };
  useEffect(() => {
    if (!selected) return;

    return keyDownListener(({ keyCode }) => {
      if (keyCode == 65) assign();
    });
  }, [macroCluster.id, activeCluster.id, selected]);
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
            width: "30px",
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
                    .map((c) => c.collected_inks)
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
