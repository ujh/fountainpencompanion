import React, { useState, useEffect } from "react";
import Jsona from "jsona";
import { getRequest } from "../fetch";
import { TablePlaceholder } from "../components/TablePlaceholder";
import { CollectedPensTable } from "./table/CollectedPensTable";

const formatter = new Jsona();

export const CollectedPens = () => {
  const [pens, setPens] = useState();

  useEffect(() => {
    async function getCollectedPens() {
      setPens(await getPens());
    }
    getCollectedPens();
  }, []);

  if (pens) {
    return <CollectedPensTable pens={pens} />;
  } else {
    return <TablePlaceholder />;
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
