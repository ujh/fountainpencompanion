import React, { useContext } from "react";

import { StateContext } from "../../micro-clusters/GenericApp";

export const LoadingOverlay = () => {
  const { updating } = useContext(StateContext);
  if (!updating) return null;
  const style = {
    position: "fixed",
    top: 0,
    left: 0,
    height: "100%",
    width: "100%",
    zIndex: 10,
    backgroundColor: "rgba(0,0,0,0.5)"
  };
  return <div style={style}></div>;
};
