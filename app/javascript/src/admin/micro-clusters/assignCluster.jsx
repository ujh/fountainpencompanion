import Jsona from "jsona";
import { putRequest } from "../../fetch";

export const assignCluster = (microClusterId, macroClusterId) =>
  putRequest(`/admins/micro_clusters/${microClusterId}.json`, {
    data: {
      id: microClusterId,
      type: "micro_cluster",
      attributes: { macro_cluster_id: macroClusterId }
    }
  })
    .then((response) => response.json())
    .then((json) => {
      const formatter = new Jsona();
      let microCluster = formatter.deserialize(json);
      microCluster.entries = microCluster.collected_inks;
      delete microCluster.collected_inks;
      return microCluster;
    });
