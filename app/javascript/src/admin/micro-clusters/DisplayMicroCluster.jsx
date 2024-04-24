import React, { useContext } from "react";

import { StateContext } from "./GenericApp";
import { DisplayMacroClusters } from "./DisplayMacroClusters";
import { CollectedInksList } from "./CollectedInksList";
import { CreateRow } from "../components/clustering/CreateRow";
import { createMacroClusterAndAssign } from "./createMacroClusterAndAssign";
import { ignoreCluster } from "./ignoreCluster";

export const DisplayMicroCluster = ({ afterCreate, assignCluster }) => {
  const { activeCluster } = useContext(StateContext);
  return (
    <div className="fpc-table fpc-table--full-width fpc-scroll-shadow">
      <table className="table">
        <thead>
          <CreateRow
            afterCreate={afterCreate}
            createMacroClusterAndAssign={createMacroClusterAndAssign}
            ignoreCluster={ignoreCluster}
            fields={["brand_name", "line_name", "ink_name"]}
          />
        </thead>
        <tbody>
          <CollectedInksList collectedInks={activeCluster.entries} />
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
