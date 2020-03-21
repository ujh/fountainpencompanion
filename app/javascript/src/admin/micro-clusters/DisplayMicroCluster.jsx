import React, { useState } from "react";
import _ from "lodash";
import { postRequest, putRequest } from "src/fetch";

export const DisplayMicroCluster = ({ data, children, afterCreate }) => {
  return (
    <table className="table">
      <thead>
        <CreateRow microCluster={data} afterCreate={afterCreate} />
      </thead>
      <tbody>
        <CollectedInksList collectedInks={data.collected_inks} />
        <tr>
          <td colSpan="8" style={{ backgroundColor: "black" }}></td>
        </tr>
        {children}
      </tbody>
    </table>
  );
};

const CreateRow = ({ microCluster, afterCreate }) => {
  const grouped = _.groupBy(microCluster.collected_inks, ci =>
    ["brand_name", "line_name", "ink_name"].map(n => ci.attributes[n]).join("")
  );
  const ci = _.maxBy(_.values(grouped), array => array.length)[0];
  const values = {
    brand_name: ci.attributes.brand_name,
    line_name: ci.attributes.line_name,
    ink_name: ci.attributes.ink_name
  };
  const [loading, setLoading] = useState(false);
  return (
    <tr>
      <th></th>
      <th>{values.brand_name}</th>
      <th>{values.line_name}</th>
      <th>{values.ink_name}</th>
      <th></th>
      <th></th>
      <th></th>
      <th>
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
      </th>
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

export const assignCluster = (microClusterId, macroClusterId, afterCreate) =>
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

export const CollectedInksList = ({ collectedInks }) => {
  const grouped = _.groupBy(collectedInks, ci =>
    ["brand_name", "line_name", "ink_name"].map(n => ci.attributes[n]).join("")
  );
  const sorted = _.reverse(_.sortBy(_.values(grouped), "length")).map(a => ({
    count: a.length,
    ci: a[0]
  }));
  return sorted.map(({ count, ci }) => {
    return (
      <tr key={ci.id}>
        <td>{count}</td>
        <td>{ci.attributes.brand_name}</td>
        <td>{ci.attributes.line_name}</td>
        <td>{ci.attributes.ink_name}</td>
        <td>{ci.attributes.maker}</td>
        <td
          style={{
            backgroundColor: ci.attributes.color,
            width: "30px"
          }}
        ></td>
        <td>
          <SearchLink ci={ci} />
        </td>
        <td></td>
      </tr>
    );
  });
};

export const SearchLink = ({ ci }) => {
  const fullName = ["brand_name", "line_name", "ink_name"]
    .map(a => ci.attributes[a])
    .join(" ");
  return (
    <a
      href={`https://google.com/search?q=${encodeURIComponent(fullName)}`}
      target="_blank"
    >
      <i className="fa fa-external-link"></i>
    </a>
  );
};
