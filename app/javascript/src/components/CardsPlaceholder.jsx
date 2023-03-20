import React from "react";
import { useDelayedRender } from "../useDelayedRender";
import { CardPlaceholder } from "./CardPlaceholder";
import "./cards.scss";

export const CardsPlaceholder = () => {
  const shouldRender = useDelayedRender(250);

  if (!shouldRender) {
    return null;
  }

  return (
    <div data-testid="cards-placeholder" className="fpc-placeholder-cards">
      <CardPlaceholder />
      <CardPlaceholder />
      <CardPlaceholder />
      <CardPlaceholder />
    </div>
  );
};
