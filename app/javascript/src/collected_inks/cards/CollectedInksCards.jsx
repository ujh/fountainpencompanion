import React, { useState } from "react";
import {} from "react";
import { Actions } from "../components";
import { Cards } from "./Cards";
import { fuzzyMatch } from "./match";

export const CollectedInksCards = ({ data, archive, onLayoutChange }) => {
  const [matchOn, setMatchOn] = useState("");
  const visible = fuzzyMatch(data, matchOn);

  return (
    <div>
      <Actions
        archive={archive}
        activeLayout="card"
        numberOfInks={data.length}
        onFilterChange={setMatchOn}
        onLayoutChange={onLayoutChange}
      />
      <Cards data={visible} />
    </div>
  );
};
