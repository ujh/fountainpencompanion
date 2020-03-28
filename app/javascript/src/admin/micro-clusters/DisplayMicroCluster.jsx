import React, { useContext } from "react";
import _ from "lodash";
import Jsona from "jsona";

import { postRequest, putRequest } from "src/fetch";
import { StateContext, DispatchContext } from "./App";
import { UPDATING, ADD_MACRO_CLUSTER } from "./actions";

export const DisplayMicroCluster = ({ children, afterCreate }) => {
  const { activeCluster } = useContext(StateContext);
  return (
    <table className="table">
      <thead>
        <CreateRow afterCreate={afterCreate} />
      </thead>
      <tbody>
        <CollectedInksList collectedInks={activeCluster.collected_inks} />
        <tr>
          <td colSpan="8" style={{ backgroundColor: "black" }}></td>
        </tr>
        {children}
      </tbody>
    </table>
  );
};

const CreateRow = ({ afterCreate }) => {
  const { updating, activeCluster } = useContext(StateContext);
  const dispatch = useContext(DispatchContext);
  const grouped = _.groupBy(activeCluster.collected_inks, ci =>
    ["brand_name", "line_name", "ink_name"].map(n => ci[n]).join(",")
  );
  const ci = _.maxBy(_.values(grouped), array => array.length)[0];
  const values = {
    brand_name: ci.brand_name,
    line_name: ci.line_name,
    ink_name: ci.ink_name
  };
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
          disabled={updating}
          value="Create"
          onClick={() => {
            createMacroClusterAndAssign(
              values,
              activeCluster.id,
              dispatch,
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
  dispatch,
  afterCreate
) => {
  dispatch({ type: UPDATING });
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
      assignCluster(microClusterId, json.data.id).then(microCluster => {
        dispatch({
          type: ADD_MACRO_CLUSTER,
          payload: microCluster.macro_cluster
        });
        afterCreate(microCluster);
      })
    );
};

export const assignCluster = (microClusterId, macroClusterId) =>
  putRequest(`/admins/micro_clusters/${microClusterId}.json`, {
    data: {
      id: microClusterId,
      type: "micro_cluster",
      attributes: { macro_cluster_id: macroClusterId }
    }
  })
    .then(response => response.json())
    .then(json => {
      const formatter = new Jsona();
      return formatter.deserialize(json);
    });

export const CollectedInksList = ({ collectedInks }) => {
  const grouped = _.groupBy(collectedInks, ci =>
    ["brand_name", "line_name", "ink_name"].map(n => ci[n]).join(",")
  );
  const sorted = _.reverse(_.sortBy(_.values(grouped), "length")).map(a => ({
    count: a.length,
    ci: a[0]
  }));
  return sorted.map(({ count, ci }) => {
    return (
      <tr key={ci.id}>
        <td>{count}</td>
        <td>{ci.brand_name}</td>
        <td>{ci.line_name}</td>
        <td>{ci.ink_name}</td>
        <td>{ci.maker}</td>
        <td
          style={{
            backgroundColor: ci.color,
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
    .map(a => ci[a])
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
