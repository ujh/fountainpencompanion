import { useContext, useEffect, useRef, useState } from "react";
import { getRequest } from "../fetch";
import "./pen_and_ink_suggestion_widget.css";
import { Widget, WidgetDataContext } from "./widgets";

const SUGGESTION_PATH = "/dashboard/widgets/pen_and_ink_suggestion.json";
const SETTINGS_PATH = "/dashboard/widgets/pen_and_ink_suggestion_settings.json";

export const POLL_INTERVAL_MS = 1000;
export const POLL_TIMEOUT_MS = 60 * 1000;

export const ERROR_MESSAGE = "Sorry, that didn't work. Please try again!";
export const TIMEOUT_MESSAGE = "Sorry, that took too long. Please try again!";
export const THROTTLED_MESSAGE =
  "You asked for a lot of suggestions in a short time. Please wait a minute and try again!";
export const CURRENTLY_INKED_LINK = "Open currently inked entry";
export const GATE_NOTE =
  "Extra instructions become available once your account is more than two weeks old and you have more than 20 inks or 20 pens.";

export const PenAndInkSuggestionWidget = ({ renderWhenInvisible }) => (
  <Widget
    header="Pen and Ink suggestion"
    subtitle="Gives suggestions on what to ink next using AI™"
    path={SETTINGS_PATH}
    renderWhenInvisible={renderWhenInvisible}
  >
    <div className="pen-and-ink-suggestion">
      <PenAndInkSuggestionWidgetContent />
    </div>
  </Widget>
);

const PenAndInkSuggestionWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const {
    instructions_allowed: instructionsAllowed,
    instructions_max_length: instructionsMaxLength
  } = data.attributes;
  const [extraInstructions, setExtraInstructions] = useState("");
  const [rejectedPairs, setRejectedPairs] = useState([]);
  const { result, loading, requestSuggestion } = useSuggestion();

  const onAsk = async () => {
    const query = suggestionQuery(instructionsAllowed ? extraInstructions : "", rejectedPairs);
    const suggestion = await requestSuggestion(query);
    if (suggestion && isPair(suggestion)) {
      setRejectedPairs((pairs) => [
        ...pairs,
        { ink_id: suggestion.ink.id, pen_id: suggestion.pen.id }
      ]);
    }
  };

  if (loading) return <Spinner />;

  return (
    <div>
      {result && <SuggestionMessage result={result} />}
      <div className="buttons">
        {result && isPair(result) && <SuggestionAction result={result} />}
        <button type="button" className="btn btn-success" onClick={onAsk}>
          {result ? "Try again!" : "Suggest something!"}
        </button>
        {instructionsAllowed ? (
          <div className="extra-instructions">
            <textarea
              aria-label="Extra instructions"
              value={extraInstructions}
              maxLength={instructionsMaxLength}
              onChange={(e) => setExtraInstructions(e.target.value)}
              placeholder="Add extra instructions, e.g. I only want ink samples ..."
            />
          </div>
        ) : (
          <div className="gate-note text-muted">{GATE_NOTE}</div>
        )}
      </div>
      {result && !isError(result) && (
        <div className="notice text-muted">
          Results provided by an AI. Do not take it too seriously. 😉
        </div>
      )}
    </div>
  );
};

const SuggestionAction = ({ result }) =>
  isCurrentlyInked(result) ? (
    <a className="btn btn-success" href={currentlyInkedUrl(result)}>
      {CURRENTLY_INKED_LINK}
    </a>
  ) : (
    <a className="btn btn-success" href={inkItUpUrl(result)}>
      Ink it Up!
    </a>
  );

const SuggestionMessage = ({ result }) => {
  const error = isError(result);
  return (
    <div
      className={error ? "suggestion text-danger" : "suggestion"}
      role={error ? "alert" : undefined}
      dangerouslySetInnerHTML={{ __html: result.message }}
    />
  );
};

const Spinner = () => (
  <div className="loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);

const useSuggestion = () => {
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const mounted = useRef(false);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  const requestSuggestion = async (query) => {
    setLoading(true);
    setResult(null);
    const suggestion = await fetchSuggestion(query, () => mounted.current);
    if (!mounted.current) return null;
    setResult(suggestion);
    setLoading(false);
    return suggestion;
  };

  return { result, loading, requestSuggestion };
};

const fetchSuggestion = async (query, isMounted) => {
  try {
    const response = await getRequest(query ? `${SUGGESTION_PATH}?${query}` : SUGGESTION_PATH);
    if (response?.status === 429) return errorResult(THROTTLED_MESSAGE);
    const { suggestion_id: suggestionId } = await readJson(response);
    if (!suggestionId) return errorResult(ERROR_MESSAGE);
    return await pollSuggestion(suggestionId, isMounted);
  } catch (error) {
    console.error("Failed to fetch suggestion:", error);
    return errorResult(ERROR_MESSAGE);
  }
};

const pollSuggestion = async (suggestionId, isMounted) => {
  const url = `${SUGGESTION_PATH}?suggestion_id=${encodeURIComponent(suggestionId)}`;
  const deadline = Date.now() + POLL_TIMEOUT_MS;
  while (Date.now() < deadline) {
    await wait(POLL_INTERVAL_MS);
    if (!isMounted()) return null;
    const suggestion = await readJson(await getRequest(url));
    if (isError(suggestion)) return errorResult(suggestion.message || ERROR_MESSAGE);
    if (suggestion.message) return suggestion;
  }
  return errorResult(TIMEOUT_MESSAGE);
};

const readJson = async (response) => {
  if (!response?.ok) throw new Error(`Request failed: ${response?.status}`);
  return response.json();
};

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const errorResult = (message) => ({ status: "error", message });

const isError = (result) => result.status === "error";

const isPair = (result) => Boolean(result.ink?.id && result.pen?.id);

const isCurrentlyInked = (result) =>
  Boolean(result.pen_currently_inked && result.currently_inked_id);

const currentlyInkedUrl = (result) =>
  `/currently_inked/${encodeURIComponent(result.currently_inked_id)}/edit`;

const inkItUpUrl = (result) =>
  `/currently_inked/new?collected_ink_id=${result.ink.id}&collected_pen_id=${result.pen.id}`;

const suggestionQuery = (extraInstructions, rejectedPairs) => {
  const params = new URLSearchParams();
  if (extraInstructions.trim()) params.set("extra_user_input", extraInstructions);
  if (rejectedPairs.length > 0) {
    params.set("rejected_suggestions", JSON.stringify(rejectedPairs));
  }
  return params.toString();
};
