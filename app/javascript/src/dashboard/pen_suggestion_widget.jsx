import React, { useContext, useMemo, useState } from "react";
import { Widget, WidgetDataContext } from "./widgets";
import "./pen_suggestion_widget.css";

export const PenSuggestionWidget = ({ renderWhenInvisible }) => (
  <Widget
    header="Pen suggestion (Beta)"
    subtitle="Suggests what pen to ink next"
    path="/api/v1/collected_pens.json"
    paginated={true}
    renderWhenInvisible={renderWhenInvisible}
  >
    <PenSuggestionWidgetContent />
  </Widget>
);

const PenSuggestionWidgetContent = () => {
  const data = useContext(WidgetDataContext);
  const pens = useMemo(() => scorePens(filterPens(data)), [data]);
  const [pickedPen, setPickedPen] = useState();

  if (pickedPen) {
    return (
      <>
        <div className="picked-pen">
          {pickedPen.brand} {pickedPen.model} {pickedPen.nib} {pickedPen.color}
        </div>
        <Button onClick={() => setPickedPen(pickPen(pens))}>Pick a pen!</Button>
      </>
    );
  } else {
    return (
      <Button onClick={() => setPickedPen(pickPen(pens))}>Pick a pen!</Button>
    );
  }
};

const Button = ({ onClick, children }) => (
  <div className="pick-button">
    <a className="btn btn-success" onClick={onClick}>
      {children}
    </a>
  </div>
);

const pickPen = (pens) => {
  const totalScore = pens.reduce((acc, pen) => acc + pen.score, 0);
  const randomValue = Math.floor(Math.random() * totalScore);

  let index = 0;
  let runningValue = pens[0].score;

  while (runningValue < randomValue) {
    index += 1;
    runningValue += pens[index].score;
  }

  return pens[index];
};

const filterPens = (pens) =>
  pens.filter((pen) => pen.archived != true).filter((pen) => pen.inked != true);

const scorePens = (pens) => {
  const usageMedian = calculateUsageMedian(pens);
  const USAGE_FACTOR = 1;
  const DAYS_SINCE_FACTOR = 1;
  return pens.map((pen) => {
    const usageScore = Math.abs(pen.usage - usageMedian);
    const daysSinceScore = Math.round(
      Math.abs(new Date() - new Date(pen.last_cleaned)) / (24 * 60 * 60 * 1000)
    );
    const score =
      USAGE_FACTOR * usageScore + DAYS_SINCE_FACTOR * daysSinceScore;
    return { ...pen, score };
  });
};

const calculateUsageMedian = (pens) => {
  const sorted = pens.map((p) => p.usage).sort((u1, u2) => u1 - u2);
  const middle = Math.floor(sorted.length / 2);
  if (middle.length % 2) return sorted[middle];

  return (sorted[middle - 1] + sorted[middle + 1]) / 2;
};
