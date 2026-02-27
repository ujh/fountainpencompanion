import React, { useState } from "react";
import { postRequest } from "../fetch";

export const App = ({ url }) => {
  const [reviewUrl, setReviewUrl] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setMessage(null);

    try {
      const response = await postRequest(url, {
        ink_review_submission: { url: reviewUrl }
      });

      if (response.ok) {
        setMessage({ type: "success", text: "Review submitted successfully. Thank you!" });
        setReviewUrl("");
      } else {
        const json = await response.json();
        const errorText = json.errors?.join(", ") || "Something went wrong. Please try again.";
        setMessage({ type: "danger", text: errorText });
      }
    } catch {
      setMessage({ type: "danger", text: "Something went wrong. Please try again." });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <h3 className="h5">Submit a review</h3>
      {message && (
        <div className={`alert alert-${message.type}`} role="alert">
          {message.text}
        </div>
      )}
      <form onSubmit={handleSubmit}>
        <div className="mb-3">
          <input
            type="text"
            className="form-control"
            placeholder="Enter the URL of the review you would like to submit"
            value={reviewUrl}
            onChange={(e) => setReviewUrl(e.target.value)}
            disabled={submitting}
          />
          <small className="form-text text-muted">
            Enter the URL of the review you would like to submit
          </small>
        </div>
        <button type="submit" className="btn btn-success mb-3" disabled={submitting}>
          {submitting ? "Submitting..." : "Submit a review"}
        </button>
      </form>
    </>
  );
};
