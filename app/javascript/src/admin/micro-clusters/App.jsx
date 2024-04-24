import React from "react";
import { getMacroClusters, updateMacroCluster } from "./macroClusters";
import { getMicroClusters } from "./microClusters";
import { assignCluster } from "./assignCluster";

import { GenericApp } from "./GenericApp";

export const App = () => (
  <GenericApp
    brandSelectorField="simplified_brand_name"
    microClusterLoader={getMicroClusters}
    macroClusterLoader={getMacroClusters}
    macroClusterUpdater={updateMacroCluster}
    assignCluster={assignCluster}
  />
);
