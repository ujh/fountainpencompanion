import { putRequest } from "../../fetch";

export const ignoreCluster = ({ id }) =>
  putRequest(`/admins/micro_clusters/${id}.json`, {
    data: {
      type: "micro_cluster",
      attributes: { ignored: true }
    }
  });
