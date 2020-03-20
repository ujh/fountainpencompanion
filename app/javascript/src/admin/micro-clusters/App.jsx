import React, { useState, useEffect } from "react";
import { getRequest } from "src/fetch";
import { Spinner } from "./Spinner";
import { DisplayMicroClusters } from "./DisplayMicroClusters";

export const App = () => {
  const microClusters = loadMicroClusters();
  if (microClusters) {
    return <DisplayMicroClusters data={microClusters} />;
  } else {
    return <Spinner />;
  }
};

const loadMicroClusters = () => {
  const [microClusters, setMicroClusters] = useState(null);
  useEffect(() => {
    getRequest("/admins/micro_clusters.json")
      .then(response => response.json())
      .then(json => {
        setMicroClusters(json);
      });
  }, []);
  return microClusters;
};
