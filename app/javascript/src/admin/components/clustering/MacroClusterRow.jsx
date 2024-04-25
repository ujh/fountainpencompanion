import React, { useCallback, useContext, useEffect, useState } from "react";
import ScrollIntoViewIfNeeded from "react-scroll-into-view-if-needed";

import { DispatchContext, StateContext } from "./App";
import { EntriesList } from "./EntriesList";
import { SearchLink } from "./SearchLink";
import { ASSIGN_TO_MACRO_CLUSTER, UPDATING } from "./actions";
import { keyDownListener } from "./keyDownListener";

export const MacroClusterRow = ({
  macroCluster,
  afterAssign,
  selected,
  assignCluster,
  fields,
  extraColumn
}) => {
  const { activeCluster, updating } = useContext(StateContext);
  const dispatch = useContext(DispatchContext);
  const [showInks, setShowInks] = useState(false);
  const onClick = () => setShowInks(!showInks);
  const assign = useCallback(() => {
    dispatch({ type: UPDATING });
    setTimeout(() => {
      assignCluster(activeCluster.id, macroCluster.id).then((microCluster) => {
        dispatch({
          type: ASSIGN_TO_MACRO_CLUSTER,
          payload: microCluster
        });
        afterAssign(microCluster);
      });
    }, 10);
  }, [activeCluster.id, afterAssign, dispatch, macroCluster.id, assignCluster]);
  useEffect(() => {
    if (!selected) return;

    return keyDownListener(({ keyCode }) => {
      if (keyCode == 65) assign();
    });
  }, [macroCluster.id, activeCluster.id, selected, assign]);
  return (
    <>
      <tr className={selected ? "selected" : ""}>
        <td className="distance" onClick={onClick}>
          <ScrollIntoViewIfNeeded active={selected}>
            {macroCluster.distance}
          </ScrollIntoViewIfNeeded>
        </td>
        {fields.map((field) => (
          <td key={field} onClick={onClick}>
            {macroCluster[field]}
          </td>
        ))}
        <td onClick={onClick}></td>
        <td onClick={onClick}>{extraColumn(macroCluster)}</td>
        <td>
          <SearchLink e={macroCluster} fields={fields} />
        </td>
        <td>
          <button
            className="btn btn-secondary"
            type="submit"
            disabled={updating}
            onClick={assign}
          >
            Assign
          </button>
        </td>
      </tr>
      {(showInks || selected) && (
        <tr>
          <td colSpan="7">
            <table className="table macro-cluster-collected-inks">
              <tbody>
                <EntriesList
                  entries={macroCluster.micro_clusters
                    .map((c) => c.entries)
                    .flat()}
                  fields={fields}
                  extraColumn={extraColumn}
                />
              </tbody>
            </table>
          </td>
        </tr>
      )}
    </>
  );
};
