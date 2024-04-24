import { postRequest } from "../../fetch";
import { groupedInks } from "./groupedInks";
import { UPDATING, ADD_MACRO_CLUSTER } from "../components/clustering/actions";
import { assignCluster } from "./assignCluster";

export const createMacroClusterAndAssign = (
  values,
  microClusterId,
  dispatch,
  afterCreate
) => {
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
            macroCluster.micro_clusters.map((c) => c.collected_inks).flat()
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
