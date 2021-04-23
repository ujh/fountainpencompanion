import React from "react";
import { useContext } from "react";
import { Widget, WidgetDataContext } from "./widgets";

export const CurrentlyInkedSummaryWidget = () => (
  <Widget
    header={<a href="/currently_inked">Currently Inked</a>}
    path="/dashboard/widgets/currently_inked_summary.json"
  >
    <CurrentlyInkedSummaryWidgetContent />
  </Widget>
);

const CurrentlyInkedSummaryWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const { active, total, usage_records } = data.attributes;
  return (
    <>
      <p>
        Right now you have <b>{active}</b> inked pens.
      </p>
      <p>
        In total you have <b>{total}</b> currently inked entries and{" "}
        <b>{usage_records}</b> <a href="/usage_records">usage records</a>.
      </p>
    </>
  );
};
