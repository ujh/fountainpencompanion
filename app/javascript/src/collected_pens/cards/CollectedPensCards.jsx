import React, { useCallback, useEffect, useState } from "react";
import * as storage from "../../localStorage";
import { Actions } from "../components/Actions";
import { Cards } from "./Cards";
import { fuzzyMatch } from "./match";

export const storageKeyHiddenFields = "fpc-collected-pens-cards-hidden-fields";

export const CollectedPensCards = ({ pens, onLayoutChange }) => {
  const [matchOn, setMatchOn] = useState("");
  const visible = fuzzyMatch(pens, matchOn);

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
        numberOfPens={pens.length}
        onFilterChange={setMatchOn}
        onLayoutChange={onLayoutChange}
        hiddenFields={hiddenFields}
        onHiddenFieldsChange={onHiddenFieldsChange}
      />
      <Cards data={visible} hiddenFields={hiddenFields} />
    </div>
  );
};
