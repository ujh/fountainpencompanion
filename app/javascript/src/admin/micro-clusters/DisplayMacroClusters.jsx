import levenshtein from "fast-levenshtein";
import React, { useContext, useEffect } from "react";

import {
  NEXT_MACRO_CLUSTER,
  PREVIOUS_MACRO_CLUSTER
} from "../components/clustering/actions";
import { keyDownListener } from "../components/clustering/keyDownListener";
import { DispatchContext } from "./GenericApp";
import { MacroClusterRows } from "../components/clustering/MacroClusterRows";

export const DisplayMacroClusters = ({ afterAssign, assignCluster }) => {
  const dispatch = useContext(DispatchContext);
  useEffect(() => {
    return keyDownListener(({ keyCode }) => {
      if (keyCode == 74) dispatch({ type: NEXT_MACRO_CLUSTER });
      if (keyCode == 75) dispatch({ type: PREVIOUS_MACRO_CLUSTER });
    });
  }, [dispatch]);
  return (
    <MacroClusterRows
      afterAssign={afterAssign}
      assignCluster={assignCluster}
      fields={["brand_name", "line_name", "ink_name"]}
      withDistance={withDistance}
      extraColumn={extraColumn}
    />
  );
};

// This is the most expensive computation in this app. Group inks by name first
// and only compare between those that are really different.
export const withDistance = (macroClusters, activeCluster) => {
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

export const extraColumn = (ci) => (
  <div
    style={{
      backgroundColor: ci.color,
      height: "45px",
      width: "45px"
    }}
  />
);
