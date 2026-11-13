import { useState } from "react";
import { deleteRequest, postRequest } from "../fetch";

export const LoveButton = ({ url, initialLoved, initialCount }) => {
  const [loved, setLoved] = useState(initialLoved);
  const [count, setCount] = useState(initialCount);
  const [pending, setPending] = useState(false);

  const toggle = async () => {
    const previous = { loved, count };
    setLoved(!loved);
    setCount(count + (loved ? -1 : 1));
    setPending(true);
    try {
      const response = loved ? await deleteRequest(url) : await postRequest(url);
      if (!response?.ok) throw new Error(`Request failed with status ${response?.status}`);
      const json = await response.json();
      setLoved(json.loved);
      setCount(json.loves_count);
    } catch {
      setLoved(previous.loved);
      setCount(previous.count);
    } finally {
      setPending(false);
    }
  };

  return (
    <>
      <button
        type="button"
        className="btn btn-link fpc-love-button__toggle"
        aria-label={loved ? "Remove love" : "Love this review"}
        aria-pressed={loved}
        disabled={pending}
        onClick={toggle}
      >
        <i className={loved ? "fa fa-heart" : "fa fa-heart-o"} aria-hidden="true" />
      </button>
      <div className="fpc-ink-review__love-count">
        {count}
        <span className="visually-hidden"> loves</span>
      </div>
    </>
  );
};
