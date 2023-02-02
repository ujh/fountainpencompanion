import React from "react";
import { SwabCard } from "./SwabCard";
import "./cards.scss";

export const Cards = ({ data }) => {
  return (
    <div className="fpc-ink-cards">
      {data.map((row, i) => (
        <SwabCard key={row.id + "i" + i} {...row} />
      ))}
    </div>
  );
};
