import React from "react";
import { SwabCard } from "./SwabCard";

export const Cards = ({ data }) => {
  return (
    <>
      {data.map((row, i) => (
        <SwabCard key={row.id + "i" + i} {...row} />
      ))}
    </>
  );
};
