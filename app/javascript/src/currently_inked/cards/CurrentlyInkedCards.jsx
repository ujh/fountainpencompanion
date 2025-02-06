import React, { useState } from "react";
import { useHiddenFields } from "../../useHiddenFields";
import { Actions } from "../components/Actions";
import { Cards } from "./Cards";
import { fuzzyMatch } from "./match";

export const storageKeyHiddenFields = "fpc-currently-inked-cards-hidden-fields";

export const CurrentlyInkedCards = ({ currentlyInked, onLayoutChange }) => {
  const [matchOn, setMatchOn] = useState("");
  const visible = fuzzyMatch(currentlyInked, matchOn);

  const { hiddenFields, onHiddenFieldsChange } = useHiddenFields(storageKeyHiddenFields);

  return (
    <div data-testid="card-layout">
      <Actions
        activeLayout="card"
        numberOfEntries={currentlyInked.length}
        onFilterChange={setMatchOn}
        onLayoutChange={onLayoutChange}
        hiddenFields={hiddenFields}
        onHiddenFieldsChange={onHiddenFieldsChange}
      />
      <Cards data={visible} hiddenFields={hiddenFields} />
    </div>
  );
};
