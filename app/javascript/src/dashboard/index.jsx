import React from "react";
import * as ReactDOM from "react-dom";
import { CurrentlyInkedSummaryWidget } from "./currently_inked_summary_widget";
import { InksGroupedByBrandWidget } from "./inks_grouped_by_brand_widget";
import { InksSummaryWidget } from "./inks_summary_widget";
import { LeaderboardRankingWidget } from "./leaderboard_ranking_widget";
import { PensGroupedByBrandWidget } from "./pens_grouped_by_brand_widget";
import { PensSummaryWidget } from "./pens_summary_widget";
import { InksVisualizationWidget } from "./inks_visualization_widget";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("dashboard");
  if (el) ReactDOM.render(<Dashboard />, el);
});

const Dashboard = () => (
  <div className="row">
    <InksSummaryWidget />
    <PensSummaryWidget />
    <CurrentlyInkedSummaryWidget />
    <LeaderboardRankingWidget />
    <InksGroupedByBrandWidget />
    <PensGroupedByBrandWidget />
    <InksVisualizationWidget />
  </div>
);
