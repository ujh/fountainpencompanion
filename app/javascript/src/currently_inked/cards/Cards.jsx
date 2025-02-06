import React from "react";
import { CurrentlyInkedCard } from "./CurrentlyInkedCard";
import "./cards.scss";

export const Cards = ({ data, hiddenFields }) => {
  return (
    <div className="fpc-currently-inked-cards">
      {data.map((row, i) => (
        <CurrentlyInkedCard key={row.id + "i" + i} hiddenFields={hiddenFields} {...row} />
      ))}
    </div>
  );
};
