import React from "react";
import { useState } from "react";
import _ from "lodash";
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
  const [extraInstructions, setExtraInstructions] = useState("");

  if (!suggestion && !loading) {
    return (
      <div className="buttons">
        <AskForSuggestion
          setSuggestion={setSuggestion}
          setLoading={setLoading}
          extraInstructions={extraInstructions}
          setExtraInstructions={setExtraInstructions}
        />
      </div>
    );
  } else if (!suggestion && loading) {
    return <Spinner />;
  } else if (_.isEmpty(suggestion)) {
    return (
      <div className="buttons">
        <AskForSuggestion
          setSuggestion={setSuggestion}
          setLoading={setLoading}
          extraInstructions={extraInstructions}
          setExtraInstructions={setExtraInstructions}
        />
      </div>
    );
  } else if (suggestion) {
    return (
      <ShowSuggestion
        suggestion={suggestion}
        setSuggestion={setSuggestion}
        setLoading={setLoading}
        extraInstructions={extraInstructions}
        setExtraInstructions={setExtraInstructions}
      />
    );
  }
};

const AskForSuggestion = ({
  setSuggestion,
  setLoading,
  text = "Suggest something!",
  extraInstructions,
  setExtraInstructions
}) => {
  const onClick = async () => {
    setLoading(true);
    setSuggestion(null);
    const url = `/dashboard/widgets/pen_and_ink_suggestion.json?extra_user_input=${encodeURIComponent(extraInstructions)}`;
    const response = await getRequest(url);
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
    <>
      <a className="btn btn-success" onClick={onClick}>
        {text}
      </a>
      <div className="extra-instructions">
        <textarea
          value={extraInstructions}
          onChange={(e) => setExtraInstructions(e.target.value)}
          placeholder="Add extra instructions, e.g. I only want ink samples ..."
        />
      </div>
    </>
  );
};

const Spinner = () => (
  <div className="loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);

const ShowSuggestion = ({
  suggestion,
  setSuggestion,
  setLoading,
  extraInstructions,
  setExtraInstructions
}) => {
  const inkId = suggestion.ink?.id;
  const penId = suggestion.pen?.id;
  let params = [];
  if (inkId) params.push(`collected_ink_id=${inkId}`);
  if (penId) params.push(`collected_pen_id=${penId}`);
  const url = `/currently_inked/new?${params.join("&")}`;
  return (
    <div>
      <div className="suggestion" dangerouslySetInnerHTML={{ __html: suggestion.message }}></div>
      <div className="buttons">
        <a className="btn btn-success" href={url}>
          Ink it Up!
        </a>
        <AskForSuggestion
          setSuggestion={setSuggestion}
          setLoading={setLoading}
          extraInstructions={extraInstructions}
          setExtraInstructions={setExtraInstructions}
          text="Try again!"
        />
      </div>
      <div className="notice text-muted">
        Results provided by an AI. Do not take it too seriously. 😉
      </div>
    </div>
  );
};
