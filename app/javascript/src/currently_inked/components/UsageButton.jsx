import React, { useState } from "react";

export const UsageButton = ({ used, id, testingMode = false }) => {
  const [displayAsUsed, setDisplayAsUsed] = useState(used);
  if (displayAsUsed) {
    return (
      <div
        className="btn btn-secondary"
        title="Already recorded usage for today"
      >
        <i className="fa fa-bookmark-o"></i>
      </div>
    );
  } else {
    return (
      <a
        className="usage btn btn-secondary"
        title="Record usage for today"
        href={`/currently_inked/${id}/usage_record`}
        data-remote="true"
        data-method="post"
        // Hack, until we have some global way of tracking the state
        onClick={(event) => {
          setDisplayAsUsed(true);
          if (testingMode) event.preventDefault();
        }}
      >
        <i className="fa fa-bookmark"></i>
      </a>
    );
  }
};
