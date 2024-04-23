import React, { useCallback, useContext, useEffect } from "react";
import _ from "lodash";
import { postRequest, putRequest } from "../../fetch";
import { StateContext, DispatchContext } from "./App";
import { groupedInks } from "./groupedInks";
import {
  UPDATING,
  ADD_MACRO_CLUSTER,
  REMOVE_MICRO_CLUSTER
} from "../components/clustering/actions";
import { assignCluster } from "./assignCluster";
import { keyDownListener } from "../components/clustering/keyDownListener";

export const CreateRow = ({ afterCreate }) => {
  const { updating, activeCluster } = useContext(StateContext);
  const dispatch = useContext(DispatchContext);
  const values = computeValues(activeCluster);
  const create = useCallback(() => {
    createMacroClusterAndAssign(
      values,
      activeCluster.id,
      dispatch,
      afterCreate
    );
  }, [activeCluster.id, afterCreate, dispatch, values]);
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
  }, [create, values]);
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
        <button
          className="btn btn-success me-2"
          type="button"
          disabled={updating}
          onClick={create}
        >
          Create
        </button>
        <button
          className="btn btn-secondary"
          type="button"
          disabled={updating}
          onClick={ignore}
        >
          Ignore
        </button>
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
    ink_name: ci.ink_name
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
          ...values
        }
      }
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
            payload: { ...macroCluster, grouped_collected_inks }
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
      attributes: { ignored: true }
    }
  });
