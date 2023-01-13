import React from "react";
import { useContext } from "react";
import { Widget, WidgetDataContext } from "./widgets";

export const InksSummaryWidget = ({ renderWhenInvisible }) => (
  <Widget
    header={<a href="/collected_inks">Inks</a>}
    path="/dashboard/widgets/inks_summary.json"
    renderWhenInvisible={renderWhenInvisible}
  >
    <InksSummaryWidgetContent />
  </Widget>
);

const InksSummaryWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const { count, used, swabbed, archived, inks_without_reviews } =
    data.attributes;
  return (
    <>
      <p>
        Your collection currently contains <b>{count}</b> inks. You have used{" "}
        <b>{used}</b> of them and you've swabbed <b>{swabbed}</b>.
      </p>
      <p>
        You have archived <b>{archived}</b> inks.
      </p>
      <InksWithoutReviews inks_without_reviews={inks_without_reviews} />
    </>
  );
};

const InksWithoutReviews = ({ inks_without_reviews }) => {
  if (inks_without_reviews) {
    return (
      <p>
        <b>{inks_without_reviews}</b> of your inks don't have a review. You can
        add reviews for them <a href="/reviews/my_missing">here</a>.
      </p>
    );
  } else {
    return <p></p>;
  }
};
