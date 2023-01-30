import React, { useState, useEffect, useMemo } from "react";
import { createRoot } from "react-dom/client";
import Jsona from "jsona";
import { getRequest } from "../fetch";
import { useScreen } from "../useScreen";
import { CollectedInksCards, CollectedInksCardsPlaceholder } from "./cards";
import { CollectedInksTable, CollectedInksTablePlaceholder } from "./table";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll("#collected-inks .app");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(
      <CollectedInks archive={el.getAttribute("data-archive") == "true"} />
    );
  });
});

const formatter = new Jsona();

/**
 * @param {{ archive: boolean }} props
 */
const CollectedInks = ({ archive }) => {
  const [inks, setInks] = useState();

  useEffect(() => {
    async function getCollectedInks() {
      const response = await getRequest("/collected_inks.json");
      const json = await response.json();
      const inks = formatter.deserialize(json);
      // let mountainOfInks = [];
      // while (mountainOfInks.length < 5000) {
      //   mountainOfInks = mountainOfInks.concat(inks);
      // }
      setInks(inks);
    }
    getCollectedInks();
  }, []);

  const visibleInks = useMemo(
    () => (inks ? inks.filter((i) => i.archived == archive) : []),
    [inks, archive]
  );

  const screen = useScreen();
  if (screen.isSmall) {
    if (inks) {
      return <CollectedInksCards data={visibleInks} archive={archive} />;
    } else {
      return <CollectedInksCardsPlaceholder />;
    }
  } else {
    if (inks) {
      return <CollectedInksTable data={visibleInks} archive={archive} />;
    } else {
      return <CollectedInksTablePlaceholder />;
    }
  }
};
