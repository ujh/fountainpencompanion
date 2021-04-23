import React from "react";
import { useContext } from "react";
import { Widget, WidgetDataContext } from "./widgets";

export const LeaderboardRankingWidget = () => (
  <Widget
    header={<a href="/pages/leaderboards">Leaderboards</a>}
    path="/dashboard/widgets/leaderboard_ranking.json"
  >
    <LeaderboardRankingWidgetContent />
  </Widget>
);

const LeaderboardRankingWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const { inks, bottles, samples, brands } = data.attributes;
  return (
    <>
      <p>
        You are in <b>{inks}.</b> place in the{" "}
        <a href="/pages/inks_leaderboard">inks</a> leaderboard.
      </p>
      <p>
        You are in <b>{bottles}.</b> place in the{" "}
        <a href="/pages/bottles_leaderboard">bottles</a> leaderboard.
      </p>
      <p>
        You are in <b>{samples}.</b> place in the{" "}
        <a href="/pages/samples_leaderboard">samples</a> leaderboard.
      </p>
      <p>
        You are in <b>{brands}.</b> place in the{" "}
        <a href="/pages/brands_leaderboard">brands</a> leaderboard.
      </p>
    </>
  );
};
