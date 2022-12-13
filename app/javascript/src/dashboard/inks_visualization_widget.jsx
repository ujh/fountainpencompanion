import React from "react";
import { useState } from "react";
import { useContext } from "react";
import { colorSort } from "../color-sorting";
import { Widget, WidgetDataContext, WidgetWidthContext } from "./widgets";

export const InksVisualizationWidget = () => (
  <Widget header={"Ink visualization"} path={dataPath}>
    <InksVisualizationWidgetContent />
  </Widget>
);

const dataPath = "/collected_inks.json?fields[collected_ink]=color,archived";

const InksVisualizationWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const [includeArchived, setIncludeArchived] = useState(false);
  const width = useContext(WidgetWidthContext);
  return (
    <>
      <div className="container">
        <div className="checkbox">
          <label
            htmlFor="include-archived"
            onClick={() => setIncludeArchived(!includeArchived)}
          >
            <input
              name="include-archived"
              type="checkbox"
              checked={includeArchived}
              onChange={() => {}}
            />
            Include archived inks
          </label>
        </div>
      </div>
      <div className="inks-visualization" style={{ height: width }}>
        {inksToDisplay(data, includeArchived).map((ink) => (
          <div
            key={ink.id}
            className="ink"
            style={{ backgroundColor: ink.attributes.color, height: 100 }}
          ></div>
        ))}
      </div>
    </>
  );
};

const inksToDisplay = (inks, includeArchived) =>
  inks
    .filter((ink) => (includeArchived ? true : !ink.attributes.archived))
    .sort(sortByColor);

const sortByColor = (inkA, inkB) =>
  colorSort(inkA.attributes.color, inkB.attributes.color);
