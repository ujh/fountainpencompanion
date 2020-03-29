import React, { useContext } from "react";
import _ from "lodash";
import { postRequest } from "src/fetch";
import { StateContext, DispatchContext } from "./App";
import { UPDATING, ADD_MACRO_CLUSTER } from "./actions";
import { assignCluster } from "./assignCluster";

export const CreateRow = ({ afterCreate }) => {
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
