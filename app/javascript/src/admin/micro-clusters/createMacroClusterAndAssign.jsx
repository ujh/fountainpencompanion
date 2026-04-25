import { postRequest } from "../../fetch";
import { ADD_MACRO_CLUSTER, UPDATING } from "../components/clustering/actions";
import { assignCluster } from "./assignCluster";
import { groupedInks } from "./groupedInks";

export const createMacroClusterAndAssign = (values, microClusterId, dispatch, afterCreate) => {
  dispatch({ type: UPDATING });
  setTimeout(() => {
    postRequest("/admins/macro_clusters.json", {
      data: {
        type: "macro_cluster",
        attributes: {
          ...values
        }
      }
    })
      .then((response) => response.json())
      .then((json) =>
        assignCluster(microClusterId, json.data.id).then((microCluster) => {
          const macroCluster = microCluster.macro_cluster;
          const grouped_entries = groupedInks(
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
