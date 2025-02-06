import React, { useContext } from "react";

import { StateContext } from "./App";
import { CreateRow } from "./CreateRow";
import { DisplayMacroClusters } from "./DisplayMacroClusters";
import { EntriesList } from "./EntriesList";

export const DisplayMicroCluster = ({
  afterCreate,
  assignCluster,
  fields,
  withDistance,
  ignoreCluster,
  extraColumn,
  createMacroClusterAndAssign
}) => {
  const { activeCluster } = useContext(StateContext);
  return (
    <div className="fpc-table fpc-table--full-width fpc-scroll-shadow">
      <table className="table">
        <thead>
          <CreateRow
            afterCreate={afterCreate}
            createMacroClusterAndAssign={createMacroClusterAndAssign}
            ignoreCluster={ignoreCluster}
            fields={fields}
          />
        </thead>
        <tbody>
          <EntriesList entries={activeCluster.entries} fields={fields} extraColumn={extraColumn} />
          <tr>
            <td colSpan={fields.length + 5} style={{ backgroundColor: "black" }}></td>
          </tr>
          <DisplayMacroClusters
            afterAssign={afterCreate}
            assignCluster={assignCluster}
            extraColumn={extraColumn}
            withDistance={withDistance}
            fields={fields}
          />
        </tbody>
      </table>
    </div>
  );
};
