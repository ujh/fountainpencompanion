import { useId, useRef, useState } from "react";
import { postRequest } from "../fetch";

const MAX_DESCRIPTION_LENGTH = 2000;
const GENERIC_ERROR = "Sending the report failed. Please try again.";

export const ReportButton = ({ url, heading, label, icon }) => {
  const dialogRef = useRef(null);
  const headingId = useId();
  const [description, setDescription] = useState("");
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState(null);

  const open = () => {
    setSent(false);
    setError(null);
    dialogRef.current.showModal();
  };

  const close = () => dialogRef.current.close();

  const submit = async (event) => {
    event.preventDefault();
    setSending(true);
    setError(null);
    try {
      const response = await postRequest(url, { description });
      if (response?.ok) {
        setSent(true);
        setDescription("");
      } else {
        setError(await errorMessage(response));
      }
    } catch {
      setError(GENERIC_ERROR);
    } finally {
      setSending(false);
    }
  };

  return (
    <>
      {icon ? (
        <button
          type="button"
          className="btn btn-link fpc-report-button__icon"
          aria-label={label}
          title={label}
          onClick={open}
        >
          <i className="fa fa-exclamation-circle" aria-hidden="true" />
        </button>
      ) : (
        <button type="button" className="btn btn-link p-0 align-baseline" onClick={open}>
          {label}
        </button>
      )}
      <dialog ref={dialogRef} className="fpc-report-dialog" aria-labelledby={headingId}>
        <h2 id={headingId} className="h5">
          {heading}
        </h2>
        {sent ? (
          <>
            <p className="text-success">Thanks! Your report was sent.</p>
            <div className="fpc-report-dialog__buttons">
              <button type="button" className="btn btn-primary" onClick={close}>
                Close
              </button>
            </div>
          </>
        ) : (
          <form onSubmit={submit}>
            <label htmlFor={`${headingId}-description`} className="form-label">
              What is wrong?
            </label>
            <textarea
              id={`${headingId}-description`}
              className="form-control"
              rows={5}
              required
              maxLength={MAX_DESCRIPTION_LENGTH}
              value={description}
              onChange={(event) => setDescription(event.target.value)}
            />
            {error && <p className="text-danger mt-2 mb-0">{error}</p>}
            <div className="fpc-report-dialog__buttons">
              <button type="button" className="btn btn-secondary" onClick={close}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary" disabled={sending}>
                Send report
              </button>
            </div>
          </form>
        )}
      </dialog>
    </>
  );
};

const errorMessage = async (response) => {
  try {
    const json = await response.json();
    return json.errors?.join(", ") || GENERIC_ERROR;
  } catch {
    return GENERIC_ERROR;
  }
};
