import React, { useCallback, useEffect, useState } from "react";
import * as storage from "../../localStorage";
import { Actions } from "../components/Actions";
import { Cards } from "./Cards";
import { fuzzyMatch } from "./match";

export const storageKeyHiddenFields = "fpc-currently-inked-cards-hidden-fields";

export const CurrentlyInkedCards = ({ currentlyInked, onLayoutChange }) => {
  const [matchOn, setMatchOn] = useState("");
  const visible = fuzzyMatch(currentlyInked, matchOn);

  const [hiddenFields, setHiddenFields] = useState([]);

  useEffect(() => {
    const fromLocalStorage = JSON.parse(
      storage.getItem(storageKeyHiddenFields)
    );
    if (fromLocalStorage) {
      setHiddenFields(fromLocalStorage);
      return;
    }

    setHiddenFields([]);
  }, [setHiddenFields]);

  const onHiddenFieldsChange = useCallback(
    (nextHiddenFields) => {
      if (nextHiddenFields === null) {
        storage.removeItem(storageKeyHiddenFields);

        setHiddenFields([]);

        return;
      }

      setHiddenFields(nextHiddenFields);
      storage.setItem(storageKeyHiddenFields, JSON.stringify(nextHiddenFields));
    },
    [setHiddenFields]
  );

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
