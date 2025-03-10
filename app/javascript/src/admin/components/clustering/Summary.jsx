import React, { useContext } from "react";

import { StateContext } from "./App";

export const Summary = () => {
  const { microClusters, selectedMicroClusters } = useContext(StateContext);
  return (
    <div className="summary">
      <b>Total:</b> {microClusters.length} <b>In Selection:</b> {selectedMicroClusters.length}
    </div>
  );
};
