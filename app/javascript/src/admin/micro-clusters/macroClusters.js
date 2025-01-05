import Jsona from "jsona";

import { getRequest } from "../../fetch";
import {
  SET_LOADING_PERCENTAGE,
  SET_MACRO_CLUSTERS,
  UPDATE_MACRO_CLUSTER
} from "../components/clustering/actions";
import { groupedInks } from "./groupedInks";

export const getMacroClusters = (dispatch) => {
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

export const updateMacroCluster = (id, dispatch) => {
  setTimeout(() => {
    getRequest(`/admins/macro_clusters/${id}.json`)
      .then((response) => response.json())
      .then((json) => {
        const formatter = new Jsona();
        const macroCluster = formatter.deserialize(json);
        const grouped_entries = groupedInks(
          macroCluster.micro_clusters.map((c) => c.collected_inks).flat()
        );
        macroCluster.micro_clusters.forEach(
          (mc) => (mc.entries = mc.collected_inks)
        );
        return { ...macroCluster, grouped_entries };
      })
      .then((macroCluster) =>
        dispatch({ type: UPDATE_MACRO_CLUSTER, payload: macroCluster })
      );
  }, 500);
};

const loadMacroClusterPage = async (page) => {
  const response = await getRequest(
    `/admins/macro_clusters.json?per_page=25&page=${page}`,
    10 // timeout after 10s
  );
  return await response.json();
};
