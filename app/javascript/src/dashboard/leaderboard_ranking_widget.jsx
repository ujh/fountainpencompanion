import React from "react";
import { useContext } from "react";
import { Widget, WidgetDataContext } from "./widgets";

export const LeaderboardRankingWidget = ({ renderWhenInvisible }) => (
  <Widget
    header={<a href="/pages/leaderboards">Leaderboards</a>}
    path="/dashboard/widgets/leaderboard_ranking.json"
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
      <InkReviewSubmissionsContent rank={ink_review_submissions} />
    </>
  );
};

const InkReviewSubmissionsContent = ({ rank }) => {
  if (rank) {
    return (
      <p>
        You are in <b>{rank}.</b> place in the{" "}
        <a href="/pages/ink_review_submissions_leaderboard">
          ink review submissions
        </a>{" "}
        leaderboard.
      </p>
    );
  } else {
    return (
      <p>
        <b>
          Submit at least one ink review to appear on the{" "}
          <a href="/pages/ink_review_submissions_leaderboard">
            ink review submissions
          </a>{" "}
          leaderboard. You can either submit a review to any ink you own or pick
          <a href="/reviews/missing"> one of the inks that have no reviews</a>.
        </b>
      </p>
    );
  }
};
