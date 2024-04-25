import React, { useContext } from "react";

import { CreateRow } from "../components/clustering/CreateRow";
import { EntriesList } from "../components/clustering/EntriesList";
import { DisplayMacroClusters } from "../components/clustering/DisplayMacroClusters";
import { StateContext } from "./GenericApp";
import { createMacroClusterAndAssign } from "./createMacroClusterAndAssign";
import { extraColumn } from "./extraColumn";
import { ignoreCluster } from "./ignoreCluster";
import { withDistance } from "./withDistance";

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
            extraColumn={extraColumn}
            withDistance={withDistance}
            fields={["brand_name", "line_name", "ink_name"]}
          />
        </tbody>
      </table>
    </div>
  );
};
