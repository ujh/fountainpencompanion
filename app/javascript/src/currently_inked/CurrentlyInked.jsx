import React, { useState, useEffect } from "react";
import Jsona from "jsona";
import { getRequest } from "../fetch";

import { TablePlaceholder } from "../components/TablePlaceholder";
import { CurrentlyInkedTable } from "./table/CurrentlyInkedTable";

const formatter = new Jsona();

export const CurrentlyInked = () => {
  const [currentlyInked, setCurrentlyInked] = useState();

  useEffect(() => {
    async function getData() {
      setCurrentlyInked(await getCurrentlyInked());
    }
    getData();
  }, []);

  if (currentlyInked) {
    return (
      <div>
        <CurrentlyInkedTable currentlyInked={currentlyInked} />
      </div>
    );
  } else {
    return (
      <div>
        <TablePlaceholder />
      </div>
    );
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
