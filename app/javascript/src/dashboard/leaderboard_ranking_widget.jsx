import React from "react";
import { useContext } from "react";
import { Widget, WidgetDataContext } from "./widgets";

export const LeaderboardRankingWidget = ({ renderWhenInvisible }) => (
  <Widget
    header="Leaderboards"
    subtitle="Your rank on the leaderboards"
    path="/dashboard/widgets/leaderboard_ranking.json"
    withLinks
    renderWhenInvisible={renderWhenInvisible}
  >
    <LeaderboardRankingWidgetContent />
  </Widget>
);

const LeaderboardRankingWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const { inks, bottles, samples, brands, ink_review_submissions } =
    data.attributes;
  return (
    <>
      <table className="mt-4 table table-borderless table-sm card-text">
        <tbody>
          <tr>
            <th className="fw-normal" scope="row">
              Inks
            </th>
            <td className="text-end">{inks}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              Bottles
            </th>
            <td className="text-end">{bottles}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              Samples
            </th>
            <td className="text-end">{samples}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              Brands
            </th>
            <td className="text-end">{brands}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              Review submissions
            </th>
            <td className="text-end">{ink_review_submissions || "Unranked"}</td>
          </tr>
        </tbody>
      </table>
      <div className="fpc-dashboard-widget__links">
        <a className="card-link" href="/pages/leaderboards">
          Leaderboards
        </a>
      </div>
    </>
  );
};
