import React from "react";
import { useContext } from "react";
import { Widget, WidgetDataContext } from "./widgets";

export const InksSummaryWidget = () => (
  <Widget
    header={<a href="/collected_inks">Inks</a>}
    path="/dashboard/widgets/inks_summary.json"
  >
    <InksSummaryWidgetContent />
  </Widget>
);

const InksSummaryWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const { count, used, swabbed, archived } = data.attributes;
  return (
    <>
      <p>
        Your collection currently contains <b>{count}</b> inks. You have used{" "}
        <b>{used}</b> of them and you've swabbed <b>{swabbed}</b>.
      </p>
      <p>
        You have archived <b>{archived}</b> inks.
      </p>
    </>
  );
};
