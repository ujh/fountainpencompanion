import React from "react";
import { useContext } from "react";
import { Widget, WidgetDataContext } from "./widgets";

export const PensSummaryWidget = ({ renderWhenInvisible }) => (
  <Widget
    header="Pens"
    path="/dashboard/widgets/pens_summary.json"
    withLinks
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
              Archived
            </th>
            <td className="text-end">{archived}</td>
          </tr>
        </tbody>
      </table>
      <div className="fpc-dashboard-widget__links">
        <a className="card-link" href="/collected_pens">
          Pens
        </a>
      </div>
    </>
  );
};
