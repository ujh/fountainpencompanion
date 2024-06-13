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
        .filter((c) => c.model_variants.length > 0)
        .map((c) => {
          const grouped_model_variants = groupedPens(c.model_variants);
          let cluster = {
            ...c,
            entries: c.model_variants,
            grouped_entries: grouped_model_variants
          };
          delete cluster.model_variants;
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
  putRequest(`/admins/pens/model_micro_clusters/${id}.json`, {
    data: {
      type: "pens_model_micro_cluster",
      attributes: { ignored: true }
    }
  });

export const assignCluster = (microClusterId, macroClusterId) =>
  putRequest(`/admins/pens/model_micro_clusters/${microClusterId}.json`, {
    data: {
      id: microClusterId,
      type: "pens_model_micro_cluster",
      attributes: { pens_model_id: macroClusterId }
    }
  })
    .then((response) => response.json())
    .then((json) => {
      const formatter = new Jsona();
      let microCluster = formatter.deserialize(json);
      microCluster.entries = microCluster.model_variants;
      delete microCluster.model_variants;
      microCluster.macro_cluster = microCluster.model;
      delete microCluster.model;
      microCluster.macro_cluster.model_micro_clusters.forEach((mc) => {
        mc.entries = mc.model_variants;
        delete mc.model_variants;
      });
      microCluster.macro_cluster.micro_clusters =
        microCluster.macro_cluster.model_micro_clusters;
      return microCluster;
    });

const loadMicroClusterPage = async (page) => {
  const response = await getRequest(
    `/admins/pens/model_micro_clusters.json?unassigned=true&without_ignored=true&page=${page}`
  );
  return await response.json();
};
