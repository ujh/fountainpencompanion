import React, { useState } from "react";
import { useHiddenFields } from "../../useHiddenFields";
import { Actions } from "../components";
import { Cards } from "./Cards";
import { fuzzyMatch } from "./match";

export const storageKeyHiddenFields = "fpc-collected-inks-cards-hidden-fields";

export const CollectedInksCards = ({ data, archive, onLayoutChange }) => {
  const [matchOn, setMatchOn] = useState("");
  const visible = fuzzyMatch(data, matchOn);

  const { hiddenFields, onHiddenFieldsChange } = useHiddenFields(storageKeyHiddenFields);

  return (
    <div>
      <Actions
        archive={archive}
        activeLayout="card"
        numberOfInks={data.length}
        onFilterChange={setMatchOn}
        onLayoutChange={onLayoutChange}
        hiddenFields={hiddenFields}
        onHiddenFieldsChange={onHiddenFieldsChange}
      />
      <Cards data={visible} hiddenFields={hiddenFields} />
    </div>
  );
};
