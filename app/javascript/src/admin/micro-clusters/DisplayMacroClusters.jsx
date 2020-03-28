import React, { useState, useContext } from "react";
import _ from "lodash";
import levenshtein from "fast-levenshtein";

import {
  CollectedInksList,
  SearchLink,
  assignCluster
} from "./DisplayMicroCluster";
import { StateContext, DispatchContext } from "./App";
import { ASSIGN_TO_MACRO_CLUSTER } from "./actions";

export const DisplayMacroClusters = ({ afterAssign }) => {
  return <MacroClustersRows afterAssign={afterAssign} />;
};

const MacroClustersRows = ({ afterAssign }) => {
  const { macroClusters, activeCluster } = useContext(StateContext);
  const withDistance = macroClusters.map(c => ({
    ...c,
    distance: dist(c, activeCluster)
  }));
  return _.sortBy(withDistance, "distance").map(macroCluster => (
    <MacroClusterRow
      key={macroCluster.id}
      macroCluster={macroCluster}
      afterAssign={afterAssign}
    />
  ));
};

const dist = (macroCluster, microCluster) => {
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
  const distances = macroCluster.micro_clusters
    .map(mi => mi.collected_inks)
    .flat()
    .map(ci1 =>
      microCluster.collected_inks
        .map(ci2 => [calc1(ci1, ci2), calc2(ci1, ci2), calc3(ci1, ci2)])
        .flat()
    )
    .flat();
  return Math.min(...distances);
};

const MacroClusterRow = ({ macroCluster, afterAssign }) => {
  const { activeCluster, updating } = useContext(StateContext);
  const dispatch = useContext(DispatchContext);
  const [showInks, setShowInks] = useState(false);
  const onClick = () => {
    setShowInks(!showInks);
  };
  return (
    <>
      <tr>
        <td className="distance" onClick={onClick}>
          {macroCluster.distance}
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
            onClick={e => {
              assignCluster(activeCluster.id, macroCluster.id).then(
                microCluster => {
                  dispatch({
                    type: ASSIGN_TO_MACRO_CLUSTER,
                    payload: microCluster
                  });
                  afterAssign(microCluster);
                }
              );
            }}
          />
        </td>
      </tr>
      {showInks && (
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
