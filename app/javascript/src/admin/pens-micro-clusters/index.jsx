import React from "react";
import { createRoot } from "react-dom/client";

import { App } from "../components/clustering/App";
import { fields } from "./fields";
import { createMacroClusterAndAssign, getMacroClusters, updateMacroCluster } from "./macroClusters";
import { assignCluster, getMicroClusters, ignoreCluster } from "./microClusters";
import { withDistance } from "./withDistance";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("pens-micro-clusters-app");
  if (el) {
    const root = createRoot(el);
    root.render(
      <App
        brandSelectorField="simplified_brand"
        fields={fields}
        microClusterLoader={getMicroClusters}
        macroClusterLoader={getMacroClusters}
        macroClusterUpdater={updateMacroCluster}
        assignCluster={assignCluster}
        withDistance={withDistance}
        ignoreCluster={ignoreCluster}
        extraColumn={extraColumn}
        createMacroClusterAndAssign={createMacroClusterAndAssign}
      />
    );
  }
});

const extraColumn = () => {};
