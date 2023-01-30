import React, { useState } from "react";
import {} from "react";
import { Actions } from "./Actions";
import { Cards } from "./Cards";
import { fuzzyMatch } from "./match";

export const CollectedInksCards = ({ data, archive }) => {
  const [matchOn, setMatchOn] = useState("");
  const visible = fuzzyMatch(data, matchOn);

  return (
    <div>
      <Actions
        archive={archive}
        numberOfInks={data.length}
        onFilterChange={setMatchOn}
      />
      <Cards data={visible} />
    </div>
  );
};
