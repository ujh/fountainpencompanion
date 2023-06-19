import React, { useState, useEffect, useCallback } from "react";
import Jsona from "jsona";
import { getRequest } from "../fetch";
import { useScreen } from "../useScreen";
import * as storage from "../localStorage";
import { CardsPlaceholder } from "../components/CardsPlaceholder";
import { TablePlaceholder } from "../components/TablePlaceholder";
import { CurrentlyInkedCards } from "./cards/CurrentlyInkedCards";
import { CurrentlyInkedTable } from "./table/CurrentlyInkedTable";

const formatter = new Jsona();

export const storageKeyLayout = "fpc-currently-inked-layout";

export const CurrentlyInked = () => {
  const [currentlyInked, setCurrentlyInked] = useState();

  useEffect(() => {
    async function getData() {
      setCurrentlyInked(await getCurrentlyInked());
    }
    getData();
  }, []);

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
    if (currentlyInked) {
      return (
        <CurrentlyInkedCards
          currentlyInked={currentlyInked}
          onLayoutChange={onLayoutChange}
        />
      );
    } else {
      return <CardsPlaceholder />;
    }
  } else {
    if (currentlyInked) {
      return (
        <CurrentlyInkedTable
          currentlyInked={currentlyInked}
          onLayoutChange={onLayoutChange}
        />
      );
    } else {
      return <TablePlaceholder />;
    }
  }
};

const getCurrentlyInked = async () => {
  let receivedCurrentlyInked = [];
  let page = 1;
  do {
    const json = await getPage(page);
    page = json.meta.pagination.next_page;
    receivedCurrentlyInked.push(...formatter.deserialize(json));
  } while (page);
  return receivedCurrentlyInked;
};

const getPage = async (page) => {
  const response = await getRequest(
    `/api/v1/currently_inked.json?filter[archived]=false&page[number]=${page}`
  );
  const json = await response.json();
  return json;
};
