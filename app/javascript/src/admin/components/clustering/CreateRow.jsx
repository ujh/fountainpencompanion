import React, { useCallback, useContext, useEffect } from "react";
import _ from "lodash";

import { StateContext, DispatchContext } from "../../micro-clusters/GenericApp";
import { REMOVE_MICRO_CLUSTER } from "./actions";
import { keyDownListener } from "./keyDownListener";

export const CreateRow = ({
  afterCreate,
  createMacroClusterAndAssign,
  ignoreCluster,
  fields
}) => {
  const { updating, activeCluster } = useContext(StateContext);
  const dispatch = useContext(DispatchContext);
  const values = computeValues(activeCluster, fields);
  const create = useCallback(() => {
    createMacroClusterAndAssign(
      values,
      activeCluster.id,
      dispatch,
      afterCreate
    );
  }, [
    activeCluster.id,
    afterCreate,
    dispatch,
    values,
    createMacroClusterAndAssign
  ]);
  const ignore = () => {
    ignoreCluster(activeCluster).then(
      dispatch({ type: REMOVE_MICRO_CLUSTER, payload: activeCluster })
    );
  };
  useEffect(() => {
    return keyDownListener(({ keyCode }) => {
      if (keyCode == 67) create();
      if (keyCode == 79) {
        const fullName = fields.map((a) => values[a]).join(" ");
        const url = `https://google.com/search?q=${encodeURIComponent(
          fullName
        )}`;
        window.open(url, "_blank");
      }
    });
  }, [create, values, fields]);
  return (
    <tr>
      <th></th>
      {fields.map((field) => (
        <th key={field}>{values[field]}</th>
      ))}
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

const computeValues = (activeCluster, fields) => {
  const grouped = _.groupBy(activeCluster.entries, (ci) =>
    fields.map((n) => ci[n]).join(",")
  );
  const ci = _.maxBy(_.values(grouped), (array) => array.length)[0];
  return {
    brand_name: ci.brand_name,
    line_name: ci.line_name,
    ink_name: ci.ink_name
  };
};
