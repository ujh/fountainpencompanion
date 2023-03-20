import React from "react";
import { PenCard } from "./PenCard";
import "./cards.scss";

export const Cards = ({ data, hiddenFields }) => {
  return (
    <div className="fpc-pen-cards">
      {data.map((row, i) => (
        <PenCard key={row.id + "i" + i} hiddenFields={hiddenFields} {...row} />
      ))}
    </div>
  );
};
