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

  if (!pens.length) {
    return <div className="picked-pen-content">All pens are in use</div>;
  }
  if (pickedPen) {
    return (
      <div className="picked-pen-content">
        <div className="pen">
          {pickedPen.brand} {pickedPen.model} {pickedPen.nib} {pickedPen.color}
        </div>
        <div className="buttons">
          <PickPenButton
            onClick={() => setPickedPen(pickPen(pens, pickedPen))}
          />
          <a
            className="btn btn-success"
            href={`/currently_inked/new?collected_pen_id=${pickedPen.id}`}
          >
            Ink in up!
          </a>
        </div>
      </div>
    );
  } else {
    return (
      <div className="picked-pen-content">
        <PickPenButton onClick={() => setPickedPen(pickPen(pens, pickedPen))} />
      </div>
    );
  }
};

const PickPenButton = ({ onClick }) => (
  <a className="btn btn-success" onClick={onClick}>
    Pick a pen!
  </a>
);

const pickPen = (pens, currenPick) => {
  const totalScore = pens.reduce((acc, pen) => acc + pen.score, 0);

  let newPick = null;
  let tries = 0;
  do {
    const randomValue = Math.floor(Math.random() * totalScore);
    let index = 0;
    let runningValue = pens[0].score;

    while (runningValue < randomValue) {
      index += 1;
      runningValue += pens[index].score;
    }

    newPick = pens[index];
    tries++;
  } while (newPick == currenPick && tries < 10);

  return newPick;
};

const filterPens = (pens) =>
  pens.filter((pen) => pen.archived != true).filter((pen) => pen.inked != true);

const scorePens = (pens) => {
  const usageMedian = calculateUsageMedian(pens);
  const USAGE_FACTOR = 5;
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
