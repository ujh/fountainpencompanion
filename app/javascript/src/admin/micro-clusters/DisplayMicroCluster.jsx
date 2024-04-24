import React, { useContext } from "react";

import { StateContext } from "./GenericApp";
import { DisplayMacroClusters } from "./DisplayMacroClusters";
import { CreateRow } from "../components/clustering/CreateRow";
import { createMacroClusterAndAssign } from "./createMacroClusterAndAssign";
import { ignoreCluster } from "./ignoreCluster";
import { EntriesList } from "../components/clustering/EntriesList";

export const DisplayMicroCluster = ({ afterCreate, assignCluster }) => {
  const { activeCluster } = useContext(StateContext);
  const fields = ["brand_name", "line_name", "ink_name"];
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
          <EntriesList
            entries={activeCluster.entries}
            fields={fields}
            extraColumn={extraColumn}
          />
          <tr>
            <td colSpan="8" style={{ backgroundColor: "black" }}></td>
          </tr>
          <DisplayMacroClusters
            afterAssign={afterCreate}
            assignCluster={assignCluster}
          />
        </tbody>
      </table>
    </div>
  );
};

const extraColumn = (ci) => (
  <div
    style={{
      backgroundColor: ci.color,
      height: "45px",
      width: "45px"
    }}
  />
);
