import React from "react";
import { useContext } from "react";
import { Widget, WidgetDataContext } from "./widgets";

export const PensSummaryWidget = ({ renderWhenInvisible }) => (
  <Widget
    header={<a href="/collected_pens">Pens</a>}
    path="/dashboard/widgets/pens_summary.json"
    renderWhenInvisible={renderWhenInvisible}
  >
    <PensSummaryWidgetContent />
  </Widget>
);

const PensSummaryWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const { count, archived } = data.attributes;
  return (
    <>
      <p>
        Your collection currently contains <b>{count}</b> pens.
      </p>
      <p>
        You have archived <b>{archived}</b> pens.
      </p>
    </>
  );
};
