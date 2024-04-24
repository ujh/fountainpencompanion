import Jsona from "jsona";
import { getRequest } from "../../fetch";
import { groupedInks } from "./groupedInks";
import { UPDATE_MACRO_CLUSTER } from "../components/clustering/actions";

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
        return { ...macroCluster, grouped_entries };
      })
      .then((macroCluster) =>
        dispatch({ type: UPDATE_MACRO_CLUSTER, payload: macroCluster })
      );
  }, 500);
};
