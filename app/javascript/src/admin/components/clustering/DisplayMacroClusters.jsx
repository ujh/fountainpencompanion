import { useContext, useEffect } from "react";
import { DispatchContext } from "./App";
import { MacroClusterRows } from "./MacroClusterRows";
import { NEXT_MACRO_CLUSTER, PREVIOUS_MACRO_CLUSTER } from "./actions";
import { keyDownListener } from "./keyDownListener";

export const DisplayMacroClusters = ({
  afterAssign,
  assignCluster,
  withDistance,
  extraColumn,
  fields
}) => {
  const dispatch = useContext(DispatchContext);
  useEffect(() => {
    return keyDownListener(({ keyCode }) => {
      if (keyCode == 74) dispatch({ type: NEXT_MACRO_CLUSTER });
      if (keyCode == 75) dispatch({ type: PREVIOUS_MACRO_CLUSTER });
    });
  }, [dispatch]);
  return (
    <MacroClusterRows
      afterAssign={afterAssign}
      assignCluster={assignCluster}
      fields={fields}
      withDistance={withDistance}
      extraColumn={extraColumn}
    />
  );
};
