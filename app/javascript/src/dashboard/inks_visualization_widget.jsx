import React from "react";
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
  const width = useContext(WidgetWidthContext);
  return (
    <div className="inks-visualization" style={{ height: width }}>
      {inksToDisplay(data).map((ink) => (
        <div
          key={ink.id}
          className="ink"
          style={{ backgroundColor: ink.attributes.color, height: 100 }}
        ></div>
      ))}
    </div>
  );
};

const inksToDisplay = (inks) =>
  inks.filter((ink) => !ink.attributes.archived).sort(sortByColor);

const sortByColor = (inkA, inkB) =>
  colorSort(inkA.attributes.color, inkB.attributes.color);
