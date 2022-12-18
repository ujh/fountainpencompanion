import React from "react";
import { useContext } from "react";
import { Widget, WidgetDataContext } from "./widgets";

export const CurrentlyInkedSummaryWidget = () => (
  <Widget
    header="Currently inked"
    path="/dashboard/widgets/currently_inked_summary.json"
    withLinks
  >
    <CurrentlyInkedSummaryWidgetContent />
  </Widget>
);

const CurrentlyInkedSummaryWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const { active, total, usage_records } = data.attributes;
  return (
    <>
      <table className="mt-4 table table-borderless table-sm card-text">
        <tbody>
          <tr>
            <th className="fw-normal" scope="row">
              Currently inked pens
            </th>
            <td className="text-end">{active}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              Total entries
            </th>
            <td className="text-end">{total}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              Usage records
            </th>
            <td className="text-end">{usage_records}</td>
          </tr>
        </tbody>
      </table>
      <div className="fpc-dashboard-widget__links">
        <a className="card-link" href="/currently_inked">
          Currently Inked
        </a>
        <a className="card-link" href="/usage_records">
          Usage records
        </a>
      </div>
    </>
  );
};
