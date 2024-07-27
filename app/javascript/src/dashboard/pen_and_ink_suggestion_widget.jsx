import React from "react";
import { useState } from "react";
import { Widget } from "./widgets";
import { getRequest } from "../fetch";
import "./pen_and_ink_suggestion_widget.css";

export const PenAndInkSuggestionWidget = ({ renderWhenInvisible }) => (
  <Widget
    header="Pen and Ink suggestion"
    subtitle="Gives suggestions on what to ink next using AI™"
    renderWhenInvisible={renderWhenInvisible}
  >
    <div className="pen-and-ink-suggestion">
      <PenAndInkSuggestionWidgetContent />
    </div>
  </Widget>
);

const PenAndInkSuggestionWidgetContent = () => {
  const [suggestion, setSuggestion] = useState();
  const [loading, setLoading] = useState();

  if (!suggestion && !loading) {
    return (
      <div className="buttons">
        <AskForSuggestion
          setSuggestion={setSuggestion}
          setLoading={setLoading}
        />
      </div>
    );
  } else if (!suggestion && loading) {
    return <Spinner />;
  } else if (suggestion) {
    return (
      <ShowSuggestion
        suggestion={suggestion}
        setSuggestion={setSuggestion}
        setLoading={setLoading}
      />
    );
  }
};

const AskForSuggestion = ({
  setSuggestion,
  setLoading,
  text = "Suggest something!"
}) => {
  const onClick = async () => {
    setLoading(true);
    setSuggestion(null);
    const response = await getRequest(
      "/dashboard/widgets/pen_and_ink_suggestion.json"
    );
    const json = await response.json();
    const suggestion_id = json.suggestion_id;
    const intervalID = setInterval(async () => {
      const response = await getRequest(
        `/dashboard/widgets/pen_and_ink_suggestion.json?suggestion_id=${suggestion_id}`
      );
      const json = await response.json();
      if (json.message) {
        setSuggestion(json);
        setLoading(false);
        clearInterval(intervalID);
      }
    }, 1000);
  };

  return (
    <a className="btn btn-success" onClick={onClick}>
      {text}
    </a>
  );
};

const Spinner = () => (
  <div className="loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);

const ShowSuggestion = ({ suggestion, setSuggestion, setLoading }) => {
  return (
    <div>
      <div
        className="suggestion"
        dangerouslySetInnerHTML={{ __html: suggestion.message }}
      ></div>
      <div className="buttons">
        <a
          className="btn btn-success"
          href={`/currently_inked/new?collected_ink_id=${suggestion.ink.id}&collected_pen_id=${suggestion.pen.id}`}
        >
          Ink it Up!
        </a>
        <AskForSuggestion
          setSuggestion={setSuggestion}
          setLoading={setLoading}
          text="Try again!"
        />
      </div>
      <div className="notice text-muted">
        Results provided by an AI. Do not take it too seriously. 😉
      </div>
    </div>
  );
};
