import React, { useCallback, useState, useEffect, useMemo } from "react";
import Jsona from "jsona";
import { getRequest } from "../fetch";
import { useScreen } from "../useScreen";
import * as storage from "../localStorage";
import { TablePlaceholder } from "../components/TablePlaceholder";
import { CollectedInksCards, CollectedInksCardsPlaceholder } from "./cards";
import { CollectedInksTable } from "./table";

const formatter = new Jsona();

export const storageKeyLayout = "fpc-collected-inks-layout";

/**
 * @param {{ archive: boolean }} props
 */
export const CollectedInks = ({ archive }) => {
  const [inks, setInks] = useState();

  useEffect(() => {
    async function getCollectedInks() {
      const response = await getRequest("/collected_inks.json");
      const json = await response.json();
      const inks = formatter.deserialize(json);
      setInks(inks);
    }
    getCollectedInks();
  }, []);

  const visibleInks = useMemo(
    () => (inks ? inks.filter((i) => i.archived == archive) : []),
    [inks, archive]
  );

  const screen = useScreen();

  const [layout, setLayout] = useState(storage.getItem(storageKeyLayout));
  const onLayoutChange = useCallback(
    (e) => {
      const nextLayout = e.target.value;
      setLayout(nextLayout);
      storage.setItem(storageKeyLayout, nextLayout);
    },
    [setLayout]
  );

  if (layout ? layout === "card" : screen.isSmall) {
    if (inks) {
      return (
        <CollectedInksCards
          data={visibleInks}
          archive={archive}
          onLayoutChange={onLayoutChange}
        />
      );
    } else {
      return <CollectedInksCardsPlaceholder />;
    }
  } else {
    if (inks) {
      return (
        <CollectedInksTable
          data={visibleInks}
          archive={archive}
          onLayoutChange={onLayoutChange}
        />
      );
    } else {
      return <TablePlaceholder />;
    }
  }
};
