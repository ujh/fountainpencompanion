import React, { useState, useEffect } from "react";
import Jsona from "jsona";
import { getRequest } from "../fetch";
import { useLayout } from "../useLayout";
import { useScreen } from "../useScreen";
import { CardsPlaceholder } from "../components/CardsPlaceholder";
import { TablePlaceholder } from "../components/TablePlaceholder";
import { CollectedPensCards } from "./cards/CollectedPensCards";
import { CollectedPensTable } from "./table/CollectedPensTable";

const formatter = new Jsona();

export const storageKeyLayout = "fpc-collected-pens-layout";

export const CollectedPens = () => {
  const [pens, setPens] = useState();

  useEffect(() => {
    async function getCollectedPens() {
      setPens(await getPens());
    }
    getCollectedPens();
  }, []);

  const screen = useScreen();
  const { layout, onLayoutChange } = useLayout(storageKeyLayout);

  if (layout ? layout === "card" : screen.isSmall) {
    if (pens) {
      return <CollectedPensCards pens={pens} onLayoutChange={onLayoutChange} />;
    } else {
      return <CardsPlaceholder />;
    }
  } else {
    if (pens) {
      return <CollectedPensTable pens={pens} onLayoutChange={onLayoutChange} />;
    } else {
      return <TablePlaceholder />;
    }
  }
};

const getPens = async () => {
  let receivedPens = [];
  let page = 1;
  do {
    const json = await getPage(page);
    page = json.meta.pagination.next_page;
    receivedPens.push(...formatter.deserialize(json));
  } while (page);
  return receivedPens;
};

const getPage = async (page) => {
  const response = await getRequest(
    `/api/v1/collected_pens.json?filter[archived]=false&page[number]=${page}`
  );
  const json = await response.json();
  return json;
};
