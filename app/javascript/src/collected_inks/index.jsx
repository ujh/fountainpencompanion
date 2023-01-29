import React, { useState, useEffect, useMemo } from "react";
import { createRoot } from "react-dom/client";
import Jsona from "jsona";
import { getRequest } from "../fetch";
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
  const [inks, setInks] = useState([]);

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
    () => inks.filter((i) => i.archived == archive),
    [inks, archive]
  );

  if (inks) {
    return <CollectedInksTable data={visibleInks} archive={archive} />;
  } else {
    return <CollectedInksTablePlaceholder />;
  }
};
