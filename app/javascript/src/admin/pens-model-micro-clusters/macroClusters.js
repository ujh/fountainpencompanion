import Jsona from "jsona";

import { getRequest, postRequest } from "../../fetch";
import {
  ADD_MACRO_CLUSTER,
  SET_LOADING_PERCENTAGE,
  SET_MACRO_CLUSTERS,
  UPDATE_MACRO_CLUSTER,
  UPDATING
} from "../components/clustering/actions";
import { groupedPens } from "./groupedPens";
import { assignCluster } from "./microClusters";

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
        const grouped_model_variants = groupedPens(
          c.model_micro_clusters.map((c) => c.model_variants).flat()
        );
        const model_micro_clusters = c.model_micro_clusters.map((c) => {
          let adjusted_cluster = { ...c, entries: c.model_variants };
          delete adjusted_cluster.model_variants;
          return adjusted_cluster;
        });
        return {
          ...c,
          micro_clusters: model_micro_clusters,
          grouped_entries: grouped_model_variants
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

export const createMacroClusterAndAssign = (
  values,
  microClusterId,
  dispatch,
  afterCreate
) => {
  dispatch({ type: UPDATING });
  setTimeout(() => {
    postRequest("/admins/pens/models.json", {
      data: {
        type: "pens_model",
        attributes: {
          ...values
        }
      }
    })
      .then((response) => response.json())
      .then((json) =>
        assignCluster(microClusterId, json.data.id).then((microCluster) => {
          const macroCluster = microCluster.macro_cluster;
          microCluster.macro_cluster = macroCluster;
          const grouped_entries = groupedPens(
            macroCluster.micro_clusters.map((c) => c.entries).flat()
          );
          dispatch({
            type: ADD_MACRO_CLUSTER,
            payload: {
              ...macroCluster,
              grouped_entries
            }
          });
          afterCreate(microCluster);
        })
      );
  }, 10);
};

export const updateMacroCluster = (id, dispatch) => {
  setTimeout(() => {
    getRequest(`/admins/pens/models/${id}.json`)
      .then((response) => response.json())
      .then((json) => {
        const formatter = new Jsona();
        const macroCluster = formatter.deserialize(json);
        const grouped_entries = groupedPens(
          macroCluster.model_micro_clusters.map((c) => c.model_variants).flat()
        );
        macroCluster.model_micro_clusters.forEach(
          (mc) => (mc.entries = mc.model_variants)
        );
        macroCluster.micro_clusters = macroCluster.model_micro_clusters;
        return { ...macroCluster, grouped_entries };
      })
      .then((macroCluster) =>
        dispatch({ type: UPDATE_MACRO_CLUSTER, payload: macroCluster })
      );
  }, 500);
};

const loadMacroClusterPage = async (page) => {
  const response = await getRequest(`/admins/pens/models.json?page=${page}`);
  return await response.json();
};
