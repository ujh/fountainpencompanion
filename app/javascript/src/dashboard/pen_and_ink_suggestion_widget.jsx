import _ from "lodash";
import { useState } from "react";
import { getRequest } from "../fetch";
import "./pen_and_ink_suggestion_widget.css";
import { Widget } from "./widgets";

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
  const [allSuggestions, setAllSuggestions] = useState([]);
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
          allSuggestions={allSuggestions}
          setAllSuggestions={setAllSuggestions}
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
          allSuggestions={allSuggestions}
          setAllSuggestions={setAllSuggestions}
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
        allSuggestions={allSuggestions}
        setAllSuggestions={setAllSuggestions}
      />
    );
  }
};

const AskForSuggestion = ({
  setSuggestion,
  setLoading,
  text = "Suggest something!",
  extraInstructions,
  setExtraInstructions,
  allSuggestions,
  setAllSuggestions
}) => {
  const onClick = async () => {
    setLoading(true);
    setSuggestion(null);
    try {
      let url = `/dashboard/widgets/pen_and_ink_suggestion.json?extra_user_input=${encodeURIComponent(extraInstructions)}`;
      if (allSuggestions.length > 0) {
        const rejectedSuggestions = allSuggestions.map((s) => ({
          ink_id: s.ink?.id,
          pen_id: s.pen?.id
        }));
        url += `&rejected_suggestions=${encodeURIComponent(JSON.stringify(rejectedSuggestions))}`;
      }
      const response = await getRequest(url);
      const json = await response.json();
      const suggestion_id = json.suggestion_id;
      const intervalID = setInterval(async () => {
        try {
          const response = await getRequest(
            `/dashboard/widgets/pen_and_ink_suggestion.json?suggestion_id=${suggestion_id}`
          );
          const json = await response.json();
          if (json.message) {
            setSuggestion(json);
            setAllSuggestions([...allSuggestions, json]);
            setLoading(false);
            clearInterval(intervalID);
          }
        } catch (error) {
          console.error("Failed to poll suggestion:", error);
          setLoading(false);
          clearInterval(intervalID);
        }
      }, 1000);
    } catch (error) {
      console.error("Failed to fetch suggestion:", error);
      setLoading(false);
    }
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
  setExtraInstructions,
  allSuggestions,
  setAllSuggestions
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
          allSuggestions={allSuggestions}
          setAllSuggestions={setAllSuggestions}
          text="Try again!"
        />
      </div>
      <div className="notice text-muted">
        Results provided by an AI. Do not take it too seriously. 😉
      </div>
    </div>
  );
};
