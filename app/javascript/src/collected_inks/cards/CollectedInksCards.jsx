import React, { useCallback, useEffect, useState } from "react";
import * as storage from "../../localStorage";
import { Actions } from "../components";
import { Cards } from "./Cards";
import { fuzzyMatch } from "./match";

export const storageKeyHiddenFields = "fpc-collected-inks-cards-hidden-fields";

export const CollectedInksCards = ({ data, archive, onLayoutChange }) => {
  const [matchOn, setMatchOn] = useState("");
  const visible = fuzzyMatch(data, matchOn);

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
