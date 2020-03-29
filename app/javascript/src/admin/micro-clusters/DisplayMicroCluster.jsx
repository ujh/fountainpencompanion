import React, { useContext } from "react";

import { StateContext } from "./App";
import { DisplayMacroClusters } from "./DisplayMacroClusters";
import { CollectedInksList } from "./CollectedInksList";
import { CreateRow } from "./CreateRow";

export const DisplayMicroCluster = ({ afterCreate }) => {
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
        <DisplayMacroClusters afterAssign={afterCreate} />
      </tbody>
    </table>
  );
};
