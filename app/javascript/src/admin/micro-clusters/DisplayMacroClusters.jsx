import React, { useState } from "react";
import _ from "lodash";
import levenshtein from "fast-levenshtein";
import { postRequest, putRequest } from "../../fetch";
import {
  CollectedInksList,
  SearchLink,
  assignCluster
} from "./DisplayMicroCluster";

export const DisplayMacroClusters = ({
  data,
  microCluster,
  afterAssign,
  loading
}) => {
  return (
    <MacroClustersRows
      data={data}
      microCluster={microCluster}
      afterAssign={afterAssign}
      loading={loading}
    />
  );
};

const MacroClustersRows = ({ data, microCluster, afterAssign, loading }) => {
  let clusters = data;
  clusters.forEach(c => (c.distance = dist(c, microCluster)));
  return _.sortBy(clusters, "distance").map(mc => (
    <MacroClusterRow
      key={mc.id}
      mc={mc}
      microCluster={microCluster}
      afterAssign={afterAssign}
      dataLoading={loading}
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

const MacroClusterRow = ({ mc, microCluster, afterAssign, dataLoading }) => {
  const [loading, setLoading] = useState(false);
  const [showInks, setShowInks] = useState(false);
  const onClick = () => {
    setShowInks(!showInks);
  };
  return (
    <>
      <tr>
        <td className="distance" onClick={onClick}>
          {mc.distance}
        </td>
        <td onClick={onClick}>{mc.brand_name}</td>
        <td onClick={onClick}>{mc.line_name}</td>
        <td onClick={onClick}>{mc.ink_name}</td>
        <td onClick={onClick}></td>
        <td
          style={{
            backgroundColor: mc.color,
            width: "30px"
          }}
          onClick={onClick}
        ></td>
        <td>
          <SearchLink ci={mc} />
        </td>
        <td>
          <input
            className="btn btn-default"
            type="submit"
            disabled={loading || dataLoading}
            value={loading ? "Assigning..." : "Assign"}
            onClick={e => {
              if (dataLoading) return;
              assignCluster(microCluster.id, mc.id, data => {
                setLoading(false);
                afterAssign(data);
              });
            }}
          />
        </td>
      </tr>
      {showInks && (
        <tr>
          <td colSpan="7">
            <table className="table macro-cluster-collected-inks">
              <tbody>
                <CollectedInksList collectedInks={mc.collected_inks} />
              </tbody>
            </table>
          </td>
        </tr>
      )}
    </>
  );
};
