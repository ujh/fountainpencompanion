import { useCallback, useState } from "react";
import * as storage from "./localStorage";

export const useLayout = (storageKey) => {
  const [layout, setLayout] = useState(storage.getItem(storageKey));
  const onLayoutChange = useCallback(
    (e) => {
      const nextLayout = e.target.value;
      setLayout(nextLayout);
      storage.setItem(storageKey, nextLayout);
    },
    [setLayout, storageKey]
  );

  return {
    layout,
    onLayoutChange
  };
};
