import React, { useState } from "react";
import _ from "lodash";
import levenshtein from "fast-levenshtein";
import { postRequest, putRequest } from "../../fetch";
import {
  CollectedInksList,
  SearchLink,
  assignCluster
} from "./DisplayMicroCluster";

export const DisplayMacroClusters = ({ data, microCluster, afterAssign }) => {
  return (
    <MacroClustersRows
      data={data}
      microCluster={microCluster}
      afterAssign={afterAssign}
      loading={data.loading}
    />
  );
};

const MacroClustersRows = ({ data, microCluster, afterAssign, loading }) => {
  let clusters = data.data;
  clusters.forEach(
    mc => (mc.collected_inks = collectedInksForMacroCluster(mc, data.included))
  );
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

const dist = (cluster1, cluster2) => {
  const calc = (c1, c2) =>
    levenshtein.get(c1.attributes.brand_name, c2.attributes.brand_name) +
    0.5 * levenshtein.get(c1.attributes.line_name, c2.attributes.line_name) +
    levenshtein.get(c1.attributes.ink_name, c2.attributes.ink_name);
  const distances = cluster1.collected_inks
    .map(ci1 => cluster2.collected_inks.map(ci2 => calc(ci1, ci2)))
    .flat();
  return Math.min(...distances);
};

const MacroClusterRow = ({ mc, microCluster, afterAssign, dataLoading }) => {
  const [loading, setLoading] = useState(false);
  const [showInks, setShowInks] = useState(false);
  return (
    <>
      <tr
        onClick={() => {
          setShowInks(!showInks);
        }}
      >
        <td className="distance">{mc.distance}</td>
        <td>{mc.attributes.brand_name}</td>
        <td>{mc.attributes.line_name}</td>
        <td>{mc.attributes.ink_name}</td>
        <td></td>
        <td
          style={{
            backgroundColor: mc.attributes.color,
            width: "30px"
          }}
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
              e.stopPropagation();
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

const collectedInksForMacroCluster = (mc, included) => {
  return mc.relationships.micro_clusters.data
    .map(mi => included.find(i => i.id == mi.id && i.type == mi.type))
    .map(mi => mi.relationships.collected_inks.data)
    .flat()
    .map(ci => included.find(i => i.id == ci.id && i.type == ci.type));
};
