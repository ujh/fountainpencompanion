import Jsona from "jsona";

import { getRequest } from "../../fetch";
import {
  SET_LOADING_PERCENTAGE,
  SET_MACRO_CLUSTERS,
  SET_MICRO_CLUSTERS
} from "../components/clustering/actions";
import { groupedInks } from "./groupedInks";

export const loadMicroClusters = (dispatch) => {
  const formatter = new Jsona();
  let data = [];
  function run(page = 1) {
    loadMicroClusterPage(page).then((json) => {
      const next_page = json.meta.pagination.next_page;
      // Remove clusters without collected inks
      // Group collected inks
      const pageData = formatter
        .deserialize(json)
        .filter((c) => c.collected_inks.length > 0)
        .map((c) => {
          const grouped_collected_inks = groupedInks(c.collected_inks);
          let cluster = {
            ...c,
            entries: c.collected_inks,
            grouped_entries: grouped_collected_inks
          };
          delete cluster.collected_inks;
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

const loadMicroClusterPage = (page) => {
  return getRequest(
    `/admins/micro_clusters.json?unassigned=true&without_ignored=true&page=${page}`
  ).then((response) => response.json());
};

export const loadMacroClusters = (dispatch) => {
  let data = [];
  const formatter = new Jsona();
  function run(page = 1) {
    loadMacroClusterPage(page).then((json) => {
      const pagination = json.meta.pagination;
      dispatch({
        type: SET_LOADING_PERCENTAGE,
        payload: (pagination.current_page * 100) / pagination.total_pages
      });
      const next_page = json.meta.pagination.next_page;
      const pageData = formatter.deserialize(json).map((c) => {
        const grouped_collected_inks = groupedInks(
          c.micro_clusters.map((c) => c.collected_inks).flat()
        );
        const micro_clusters = c.micro_clusters.map((c) => {
          let adjusted_cluster = { ...c, entries: c.collected_inks };
          delete adjusted_cluster.collected_inks;
          return adjusted_cluster;
        });
        return {
          ...c,
          micro_clusters,
          grouped_entries: grouped_collected_inks
        };
      });
      data = [...data, ...pageData];
      if (next_page) {
        run(next_page);
      } else {
        dispatch({ type: SET_MACRO_CLUSTERS, payload: data });
      }
    });
  }
  run();
};

const loadMacroClusterPage = (page) => {
  return getRequest(`/admins/macro_clusters.json?page=${page}`).then(
    (response) => response.json()
  );
};
