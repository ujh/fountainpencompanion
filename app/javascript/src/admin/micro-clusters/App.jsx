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
    const data = { data: [], included: [] };
    function run(page = 1) {
      loadMicroClusterPage(page).then(json => {
        const next_page = json.meta.pagination.next_page;
        if (next_page) {
          data.data = [...data.data, ...json.data];
          data.included = [...data.included, ...json.included];
          run(next_page);
        } else {
          setMicroClusters(data);
        }
      });
    }
    run();
  }, []);
  return microClusters;
};

const loadMicroClusterPage = page => {
  return getRequest(`/admins/micro_clusters.json?page=${page}`).then(response =>
    response.json()
  );
};
