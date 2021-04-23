import React from "react";
import * as ReactDOM from "react-dom";
import { CurrentlyInkedSummaryWidget } from "./currently_inked_summary_widget";
import { InksSummaryWidget } from "./inks_summary_widget";
import { LeaderboardRankingWidget } from "./leaderboard_ranking_widget";
import { PensSummaryWidget } from "./pens_summary_widget";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("dashboard");
  ReactDOM.render(<Dashboard />, el);
});

const Dashboard = () => (
  <div className="row">
    <InksSummaryWidget />
    <PensSummaryWidget />
    <CurrentlyInkedSummaryWidget />
    <LeaderboardRankingWidget />
  </div>
);
