import Jsona from "jsona";
import { putRequest } from "src/fetch";

export const assignCluster = (microClusterId, macroClusterId) =>
  putRequest(`/admins/micro_clusters/${microClusterId}.json`, {
    data: {
      id: microClusterId,
      type: "micro_cluster",
      attributes: { macro_cluster_id: macroClusterId }
    }
  })
    .then(response => response.json())
    .then(json => {
      const formatter = new Jsona();
      return formatter.deserialize(json);
    });
