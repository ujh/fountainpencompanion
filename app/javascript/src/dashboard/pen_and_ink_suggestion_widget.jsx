import React from "react";
import { useContext, useState } from "react";
import _ from "lodash";
import { Widget, WidgetDataContext } from "./widgets";
import { getRequest } from "../fetch";
import "./pen_and_ink_suggestion_widget.css";

export const PenAndInkSuggestionWidget = ({ renderWhenInvisible }) => (
  <Widget
    header="Pen and Ink suggestion"
    subtitle="Gives suggestions on what to ink next using AI™"
    path="/dashboard/widgets/inks_summary.json"
    renderWhenInvisible={renderWhenInvisible}
  >
    <div className="pen-and-ink-suggestion">
      <PenAndInkSuggestionWidgetContent />
    </div>
  </Widget>
);

const PenAndInkSuggestionWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const { by_kind } = data.attributes;
  const [suggestion, setSuggestion] = useState();
  const [loading, setLoading] = useState();
  const [inkKind, setInkKind] = useState("");

  if (!suggestion && !loading) {
    return (
      <div className="buttons">
        <AskForSuggestion
          setSuggestion={setSuggestion}
          setLoading={setLoading}
          inkCounts={by_kind}
          inkKind={inkKind}
          setInkKind={setInkKind}
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
          inkCounts={by_kind}
          inkKind={inkKind}
          setInkKind={setInkKind}
        />
      </div>
    );
  } else if (suggestion) {
    return (
      <ShowSuggestion
        suggestion={suggestion}
        setSuggestion={setSuggestion}
        setLoading={setLoading}
        inkCounts={by_kind}
        inkKind={inkKind}
        setInkKind={setInkKind}
      />
    );
  }
};

const AskForSuggestion = ({
  setSuggestion,
  setLoading,
  inkCounts,
  inkKind,
  setInkKind,
  text = "Suggest something!"
}) => {
  const onClick = async () => {
    setLoading(true);
    setSuggestion(null);
    const url = `/dashboard/widgets/pen_and_ink_suggestion.json${inkKind ? `?ink_kind=${inkKind}` : ""}`;
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
      {Object.entries(inkCounts) && (
        <div className="filter">
          Restrict selection to ink type:{" "}
          <select
            defaultValue={inkKind}
            onChange={(e) => setInkKind(e.target.value)}
          >
            <option key="all" value=""></option>
            {Object.entries(inkCounts).map(([k, v]) => (
              <option key={k} value={k}>
                {k} ({v})
              </option>
            ))}
          </select>
        </div>
      )}
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
  inkCounts,
  inkKind,
  setInkKind
}) => {
  const inkId = suggestion.ink?.id;
  const penId = suggestion.pen?.id;
  let params = [];
  if (inkId) params.push(`collected_ink_id=${inkId}`);
  if (penId) params.push(`collected_pen_id=${penId}`);
  const url = `/currently_inked/new?${params.join("&")}`;
  return (
    <div>
      <div
        className="suggestion"
        dangerouslySetInnerHTML={{ __html: suggestion.message }}
      ></div>
      <div className="buttons">
        <a className="btn btn-success" href={url}>
          Ink it Up!
        </a>
        <AskForSuggestion
          setSuggestion={setSuggestion}
          setLoading={setLoading}
          inkCounts={inkCounts}
          inkKind={inkKind}
          setInkKind={setInkKind}
          text="Try again!"
        />
      </div>
      <div className="notice text-muted">
        Results provided by an AI. Do not take it too seriously. 😉
      </div>
    </div>
  );
};
