import React from "react";
import { useContext } from "react";
import { Widget, WidgetDataContext } from "./widgets";

export const InksSummaryWidget = ({ renderWhenInvisible }) => (
  <Widget
    header="Inks"
    path="/dashboard/widgets/inks_summary.json"
    withLinks
    renderWhenInvisible={renderWhenInvisible}
  >
    <InksSummaryWidgetContent />
  </Widget>
);

const InksSummaryWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const { count, used, swabbed, archived } = data.attributes;
  return (
    <>
      <table className="mt-4 table table-borderless table-sm card-text">
        <tbody>
          <tr>
            <th className="fw-normal" scope="row">
              Collection
            </th>
            <td className="text-end">{count}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              Used
            </th>
            <td className="text-end">{used}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              Swabbed
            </th>
            <td className="text-end">{swabbed}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              Archived
            </th>
            <td className="text-end">{archived}</td>
          </tr>
        </tbody>
      </table>
      <div className="fpc-dashboard-widget__links">
        <a className="card-link" href="/collected_inks">
          Inks
        </a>
      </div>
    </>
  );
};
