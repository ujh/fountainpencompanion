import React, { useState, useEffect, useMemo } from "react";
import Jsona from "jsona";
import { getRequest } from "../fetch";
import { useLayout } from "../useLayout";
import { useScreen } from "../useScreen";
import { CardsPlaceholder } from "../components/CardsPlaceholder";
import { TablePlaceholder } from "../components/TablePlaceholder";
import { CollectedInksCards } from "./cards";
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
  const { layout, onLayoutChange } = useLayout(storageKeyLayout);

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
      return <CardsPlaceholder />;
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
