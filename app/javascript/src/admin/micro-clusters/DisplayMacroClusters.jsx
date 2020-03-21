import React, { useState } from "react";
import _ from "lodash";
import { postRequest, putRequest } from "../../fetch";

export const DisplayMacroClusters = ({ data, microCluster }) => {
  return (
    <div>
      <table className="table table-striped">
        <thead>
          <tr>
            <th>Brand</th>
            <th>Line</th>
            <th>Ink</th>
            <th></th>
          </tr>
          <AssignedMacroClusterRow data={data} microCluster={microCluster} />
        </thead>
        <tbody>
          <CreateRow key={microCluster.id} microCluster={microCluster} />
          <MacroClustersRows data={data} microCluster={microCluster} />
        </tbody>
      </table>
    </div>
  );
};

const MacroClustersRows = ({ data, microCluster }) => {
  let clusters = data.data;
  const assignedCluster = getAssignedMacroCluster(data, microCluster);
  if (assignedCluster) {
    clusters = clusters.filter(mc => mc.id != assignedCluster.id);
  }
  return clusters.map(mc => (
    <tr key={mc.id}>
      <td>{mc.attributes.brand_name}</td>
      <td>{mc.attributes.line_name}</td>
      <td>{mc.attributes.ink_name}</td>
      <td></td>
    </tr>
  ));
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
const CreateRow = ({ microCluster }) => {
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
      <td>
        <input
          className="btn btn-default"
          type="submit"
          disabled={loading}
          value={loading ? "Creating ..." : "Create"}
          onClick={() => {
            createMacroClusterAndAssign(values, microCluster.id, setLoading);
          }}
        />
      </td>
    </tr>
  );
};

const createMacroClusterAndAssign = (values, microClusterId, setLoading) => {
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
      putRequest(`/admins/micro_clusters/${microClusterId}.json`, {
        data: {
          id: microClusterId,
          type: "micro_cluster",
          attributes: { macro_cluster_id: json.data.id }
        }
      }).then(() => setLoading(false))
    );
};
