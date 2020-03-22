import React, { useState, useEffect, useMemo } from "react";
import Select from "react-select";
import _ from "lodash";
import { getRequest } from "src/fetch";
import { Spinner } from "./Spinner";
import { DisplayMicroClusters } from "./DisplayMicroClusters";

export const App = () => {
  const microClusters = loadMicroClusters();
  const [selectedBrands, setSelectedBrands] = useState([]);
  const [selectedMicroClusters, setSelectedMicroClusters] = useState(
    microClusters
  );
  useEffect(() => {
    if (!microClusters) return;
    if (selectedBrands.length) {
      setSelectedMicroClusters({
        included: microClusters.included,
        data: microClusters.data.filter(c =>
          selectedBrands.includes(c.attributes.simplified_brand_name)
        )
      });
    } else {
      setSelectedMicroClusters(microClusters);
    }
  }, [selectedBrands, microClusters]);
  if (selectedMicroClusters) {
    return (
      <div>
        <BrandSelector
          microClusters={microClusters}
          onChange={setSelectedBrands}
        />
        <DisplayMicroClusters
          microClusters={selectedMicroClusters}
          onDone={() => {
            setSelectedBrands([]);
          }}
        />
      </div>
    );
  } else {
    return <Spinner />;
  }
};

const BrandSelector = ({ microClusters, onChange }) => {
  const values = _.countBy(
    microClusters.data.map(c => c.attributes.simplified_brand_name)
  );
  const options = _.map(values, (value, key) => ({
    value: key,
    label: `${key} (${value})`
  }));
  return (
    <div>
      <Select
        options={options}
        onChange={selected => onChange((selected || []).map(s => s.value))}
        isMulti
      />
    </div>
  );
};
const loadMicroClusters = () => {
  const [microClusters, setMicroClusters] = useState(null);
  useEffect(() => {
    const data = { data: [], included: [] };
    function run(page = 1) {
      loadMicroClusterPage(page).then(json => {
        const next_page = json.meta.pagination.next_page;
        data.data = [...data.data, ...json.data];
        data.included = [...data.included, ...json.included];
        if (next_page) {
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
  return getRequest(
    `/admins/micro_clusters.json?unassigned=true&page=${page}`
  ).then(response => response.json());
};
