import React, { useState } from "react";
import _ from "lodash";
import levenshtein from "fast-levenshtein";
import { postRequest, putRequest } from "../../fetch";
import { CollectedInksList } from "./DisplayMicroCluster";

export const DisplayMacroClusters = ({ data, microCluster, afterAssign }) => {
  return (
    <>
      <tr>
        <th></th>
        <th>Brand</th>
        <th>Line</th>
        <th>Ink</th>
        <th></th>
        <th></th>
        <th></th>
      </tr>
      <AssignedMacroClusterRow data={data} microCluster={microCluster} />
      <CreateRow
        key={microCluster.id}
        microCluster={microCluster}
        afterCreate={afterAssign}
      />
      <MacroClustersRows
        data={data}
        microCluster={microCluster}
        afterAssign={afterAssign}
      />
    </>
  );
};

const MacroClustersRows = ({ data, microCluster, afterAssign }) => {
  let clusters = data.data;
  clusters.forEach(
    mc => (mc.collected_inks = collectedInksForMacroCluster(mc, data.included))
  );
  const assignedCluster = getAssignedMacroCluster(data, microCluster);
  if (assignedCluster) {
    clusters = clusters.filter(mc => mc.id != assignedCluster.id);
  }
  clusters.forEach(c => (c.distance = dist(c, microCluster)));
  return _.sortBy(clusters, "distance").map(mc => (
    <MacroClusterRow
      key={mc.id}
      mc={mc}
      microCluster={microCluster}
      afterAssign={afterAssign}
    />
  ));
};

const dist = (cluster1, cluster2) => {
  const str = c =>
    ["brand_name", "line_name", "ink_name"].map(a => c.attributes[a]).join("");
  const distances = cluster1.collected_inks
    .map(ci1 =>
      cluster2.collected_inks.map(ci2 => levenshtein.get(str(ci1), str(ci2)))
    )
    .flat();
  return Math.min(...distances);
};

const MacroClusterRow = ({ mc, microCluster, afterAssign }) => {
  const [loading, setLoading] = useState(false);
  return (
    <>
      <tr>
        <td>{mc.distance}</td>
        <td>{mc.attributes.brand_name}</td>
        <td>{mc.attributes.line_name}</td>
        <td>{mc.attributes.ink_name}</td>
        <td
          style={{
            backgroundColor: mc.attributes.color,
            width: "30px"
          }}
        ></td>

        <td colSpan="2">
          <input
            className="btn btn-default"
            type="submit"
            disabled={loading}
            value={loading ? "Assigning..." : "Assign"}
            onClick={() => {
              assignCluster(microCluster.id, mc.id, data => {
                setLoading(false);
                afterAssign(data);
              });
            }}
          />
        </td>
      </tr>
      <tr>
        <td colSpan="7">
          <table className="table macro-cluster-collected-inks">
            <tbody>
              <CollectedInksList collectedInks={mc.collected_inks} />
            </tbody>
          </table>
        </td>
      </tr>
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

const getAssignedMacroCluster = (data, microCluster) => {
  const macroClusterRel = microCluster.relationships.macro_cluster.data;
  if (macroClusterRel) {
    return data.data.find(mc => mc.id == macroClusterRel.id);
  }
};

const AssignedMacroClusterRow = ({ data, microCluster }) => {
  const macroClusterRow = getAssignedMacroCluster(data, microCluster);
  if (macroClusterRow) {
    return (
      <tr>
        <th>{macroClusterRow.attributes.brand_name}</th>
        <th>{macroClusterRow.attributes.line_name}</th>
        <th>{macroClusterRow.attributes.ink_name}</th>
      </tr>
    );
  } else {
    return null;
  }
};
const CreateRow = ({ microCluster, afterCreate }) => {
  const grouped = _.groupBy(microCluster.collected_inks, ci =>
    ["brand_name", "line_name", "ink_name"].map(n => ci.attributes[n]).join("")
  );
  const ci = _.maxBy(_.values(grouped), array => array.length)[0];
  const [values, setValues] = useState({
    brand_name: ci.attributes.brand_name,
    line_name: ci.attributes.line_name,
    ink_name: ci.attributes.ink_name
  });
  const [loading, setLoading] = useState(false);
  return (
    <tr>
      <td></td>
      <td>
        <input
          type="text"
          name="brand_name"
          value={values.brand_name}
          onChange={event => {
            setValues({ ...values, brand_name: event.target.value });
          }}
        />
      </td>
      <td>
        <input
          type="text"
          name="line_name"
          value={values.line_name}
          onChange={event => {
            setValues({ ...values, line_name: event.target.value });
          }}
        />
      </td>
      <td>
        <input
          type="text"
          name="ink_name"
          value={values.ink_name}
          onChange={event => {
            setValues({ ...values, ink_name: event.target.value });
          }}
        />
      </td>
      <td colSpan="3">
        <input
          className="btn btn-default"
          type="submit"
          disabled={loading}
          value={loading ? "Creating ..." : "Create"}
          onClick={() => {
            createMacroClusterAndAssign(
              values,
              microCluster.id,
              setLoading,
              afterCreate
            );
          }}
        />
      </td>
    </tr>
  );
};

const createMacroClusterAndAssign = (
  values,
  microClusterId,
  setLoading,
  afterCreate
) => {
  setLoading(true);
  postRequest("/admins/macro_clusters.json", {
    data: {
      type: "macro_cluster",
      attributes: {
        ...values
      }
    }
  })
    .then(response => response.json())
    .then(json =>
      assignCluster(microClusterId, json.data.id, data => {
        setLoading(false);
        afterCreate(data);
      })
    );
};

const assignCluster = (microClusterId, macroClusterId, afterCreate) =>
  putRequest(`/admins/micro_clusters/${microClusterId}.json`, {
    data: {
      id: microClusterId,
      type: "micro_cluster",
      attributes: { macro_cluster_id: macroClusterId }
    }
  })
    .then(response => response.json())
    .then(json => {
      afterCreate(json.data);
    });
