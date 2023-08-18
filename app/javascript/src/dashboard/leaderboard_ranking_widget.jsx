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
  const {
    inks,
    bottles,
    samples,
    brands,
    ink_review_submissions,
    description_edits
  } = data.attributes;
  return (
    <>
      <table className="mt-4 table table-borderless table-sm card-text">
        <tbody>
          <tr>
            <th className="fw-normal" scope="row">
              <a href="/pages/inks_leaderboard">Inks</a>
            </th>
            <td className="text-end">{inks}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              <a href="/pages/bottles_leaderboard">Bottles</a>
            </th>
            <td className="text-end">{bottles}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              <a href="/pages/samples_leaderboard">Samples</a>
            </th>
            <td className="text-end">{samples}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              <a href="/pages/brands_leaderboard">Brands</a>
            </th>
            <td className="text-end">{brands}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              <a href="/pages/ink_review_submissions_leaderboard">
                Review submissions
              </a>
            </th>
            <td className="text-end">{ink_review_submissions || "Unranked"}</td>
          </tr>
          <tr>
            <th className="fw-normal" scope="row">
              <a href="/pages/users_by_description_edits_leaderboard">
                Description edits
              </a>
            </th>
            <td className="text-end">{description_edits || "Unranked"}</td>
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
