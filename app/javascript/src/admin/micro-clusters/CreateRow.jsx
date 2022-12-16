import React, { useContext, useEffect } from "react";
import _ from "lodash";
import { postRequest, putRequest } from "src/fetch";
import { StateContext, DispatchContext, groupedInks } from "./App";
import { UPDATING, ADD_MACRO_CLUSTER, REMOVE_MICRO_CLUSTER } from "./actions";
import { assignCluster } from "./assignCluster";
import { keyDownListener } from "./keyDownListener";

export const CreateRow = ({ afterCreate }) => {
  const { updating, activeCluster } = useContext(StateContext);
  const dispatch = useContext(DispatchContext);
  const values = computeValues(activeCluster);
  const create = () => {
    createMacroClusterAndAssign(
      values,
      activeCluster.id,
      dispatch,
      afterCreate
    );
  };
  const ignore = () => {
    ignoreCluster(activeCluster).then(
      dispatch({ type: REMOVE_MICRO_CLUSTER, payload: activeCluster })
    );
  };
  useEffect(() => {
    return keyDownListener(({ keyCode }) => {
      if (keyCode == 67) create();
      if (keyCode == 79) {
        const fullName = ["brand_name", "line_name", "ink_name"]
          .map((a) => values[a])
          .join(" ");
        const url = `https://google.com/search?q=${encodeURIComponent(
          fullName
        )}`;
        window.open(url, "_blank");
      }
    });
  }, [activeCluster.id]);
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
        <div>
          <button
            className="btn btn-primary mb-2"
            type="button"
            disabled={updating}
            onClick={create}
          >
            Create
          </button>
        </div>
        <div>
          <button
            className="btn btn-secondary"
            type="button"
            disabled={updating}
            onClick={ignore}
          >
            Ignore
          </button>
        </div>
      </th>
    </tr>
  );
};

const computeValues = (activeCluster) => {
  const grouped = _.groupBy(activeCluster.collected_inks, (ci) =>
    ["brand_name", "line_name", "ink_name"].map((n) => ci[n]).join(",")
  );
  const ci = _.maxBy(_.values(grouped), (array) => array.length)[0];
  return {
    brand_name: ci.brand_name,
    line_name: ci.line_name,
    ink_name: ci.ink_name,
  };
};

const createMacroClusterAndAssign = (
  values,
  microClusterId,
  dispatch,
  afterCreate
) => {
  dispatch({ type: UPDATING });
  setTimeout(() => {
    postRequest("/admins/macro_clusters.json", {
      data: {
        type: "macro_cluster",
        attributes: {
          ...values,
        },
      },
    })
      .then((response) => response.json())
      .then((json) =>
        assignCluster(microClusterId, json.data.id).then((microCluster) => {
          const macroCluster = microCluster.macro_cluster;
          const grouped_collected_inks = groupedInks(
            macroCluster.micro_clusters.map((c) => c.collected_inks).flat()
          );
          dispatch({
            type: ADD_MACRO_CLUSTER,
            payload: { ...macroCluster, grouped_collected_inks },
          });
          afterCreate(microCluster);
        })
      );
  }, 10);
};

const ignoreCluster = ({ id }) =>
  putRequest(`/admins/micro_clusters/${id}.json`, {
    data: {
      type: "micro_cluster",
      attributes: { ignored: true },
    },
  });
