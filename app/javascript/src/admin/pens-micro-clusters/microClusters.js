import Jsona from "jsona";

import { getRequest, putRequest } from "../../fetch";
import {
  SET_LOADING_PERCENTAGE,
  SET_MICRO_CLUSTERS
} from "../components/clustering/actions";
import { groupedPens } from "./groupedPens";

export const getMicroClusters = (dispatch) => {
  const formatter = new Jsona();
  let data = [];
  function run(page = 1) {
    loadMicroClusterPage(page).then((json) => {
      const pagination = json.meta.pagination;
      dispatch({
        type: SET_LOADING_PERCENTAGE,
        payload: (pagination.current_page * 100) / pagination.total_pages
      });
      const next_page = json.meta.pagination.next_page;
      // Remove clusters without collected inks
      // Group collected inks
      const pageData = formatter
        .deserialize(json)
        .filter((c) => c.collected_pens.length > 0)
        .map((c) => {
          const grouped_collected_pens = groupedPens(c.collected_pens);
          let cluster = {
            ...c,
            entries: c.collected_pens,
            grouped_entries: grouped_collected_pens
          };
          delete cluster.collected_pens;
          return cluster;
        });
      data = [...data, ...pageData];
      if (next_page) {
        run(next_page);
      } else {
        dispatch({ type: SET_MICRO_CLUSTERS, payload: data });
      }
    });
  }
  run();
};

export const ignoreCluster = ({ id }) =>
  putRequest(`/admins/pens/micro_clusters/${id}.json`, {
    data: {
      type: "pens_micro_cluster",
      attributes: { ignored: true }
    }
  });

export const assignCluster = (microClusterId, macroClusterId) =>
  putRequest(`/admins/pens/micro_clusters/${microClusterId}.json`, {
    data: {
      id: microClusterId,
      type: "pens_micro_cluster",
      attributes: { pens_model_variant_id: macroClusterId }
    }
  })
    .then((response) => response.json())
    .then((json) => {
      const formatter = new Jsona();
      let microCluster = formatter.deserialize(json);
      microCluster.entries = microCluster.collected_pens;
      delete microCluster.collected_pens;
      microCluster.macro_cluster = microCluster.model_variant;
      delete microCluster.model_variant;
      microCluster.macro_cluster.micro_clusters.forEach((mc) => {
        mc.entries = mc.collected_pens;
        delete mc.collected_pens;
      });
      return microCluster;
    });

const loadMicroClusterPage = async (page) => {
  let search = `unassigned=true&without_ignored=true&page=${page}`;
  var match = location.search.match(/count=\d+/);
  if (match) {
    search = `${search}&${match[0]}`;
  }
  const response = await getRequest(
    `/admins/pens/micro_clusters.json?${search}`
  );
  return await response.json();
};
