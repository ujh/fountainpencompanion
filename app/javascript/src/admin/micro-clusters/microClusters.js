import Jsona from "jsona";

import { getRequest } from "../../fetch";
import { SET_MICRO_CLUSTERS } from "../components/clustering/actions";
import { groupedInks } from "./groupedInks";

export const getMicroClusters = (dispatch) => {
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
