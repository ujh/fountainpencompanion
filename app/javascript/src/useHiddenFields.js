import { useCallback, useEffect, useState } from "react";
import * as storage from "./localStorage";

export const useHiddenFields = (storageKey, defaultHiddenFields) => {
  const [hiddenFields, setHiddenFields] = useState(defaultHiddenFields || []);

  useEffect(() => {
    const fromLocalStorage = JSON.parse(storage.getItem(storageKey));
    if (fromLocalStorage) {
      setHiddenFields(fromLocalStorage); // eslint-disable-line react-hooks/set-state-in-effect
      return;
    }

    setHiddenFields(defaultHiddenFields || []);
  }, [setHiddenFields, storageKey, defaultHiddenFields]);

  const onHiddenFieldsChange = useCallback(
    (nextHiddenFields) => {
      if (nextHiddenFields === null) {
        storage.removeItem(storageKey);

        setHiddenFields(defaultHiddenFields || []);

        return;
      }

      setHiddenFields(nextHiddenFields);
      storage.setItem(storageKey, JSON.stringify(nextHiddenFields));
    },
    [setHiddenFields, storageKey, defaultHiddenFields]
  );

  return {
    hiddenFields,
    onHiddenFieldsChange
  };
};
