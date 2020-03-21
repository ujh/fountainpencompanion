import React, { useState, useEffect } from "react";
import { getRequest } from "src/fetch";
import { Spinner } from "./Spinner";
import { DisplayMicroClusters } from "./DisplayMicroClusters";

export const App = () => {
  const microClusters = loadMicroClusters();
  const macroClusters = loadMacroClusters();
  if (microClusters) {
    return (
      <DisplayMicroClusters
        microClusters={microClusters}
        macroClusters={macroClusters}
      />
    );
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
        // if (next_page) {
        data.data = [...data.data, ...json.data];
        data.included = [...data.included, ...json.included];
        //   run(next_page);
        // } else {
        setMicroClusters(data);
        // }
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

const loadMacroClusters = () => {
  const [macroClusters, setMacroClusters] = useState(null);
  useEffect(() => {
    const data = { data: [], included: [] };
    function run(page = 1) {
      loadMacroClusterPage(page).then(json => {
        const next_page = json.meta.pagination.next_page;
        if (next_page) {
          data.data = [...data.data, ...json.data];
          data.included = [...data.included, ...json.included];
          run(next_page);
        } else {
          setMacroClusters(data);
        }
      });
    }
    run();
  }, []);
  return macroClusters;
};

const loadMacroClusterPage = page => {
  return getRequest(`/admins/macro_clusters.json?page=${page}`).then(response =>
    response.json()
  );
};
