import React, { useState } from "react";

export const ActionsCell = ({ id, refillable, ink_name, used_today }) => {
  return (
    <div className="actions">
      <UsageButton id={id} used={used_today} />
      {refillable && (
        <a
          className="btn btn-secondary"
          title="Refill this pen"
          href={`/currently_inked/${id}/refill`}
          data-method="post"
          data-confirm={`Really refill ${ink_name}?`}
        >
          <i className="fa fa-rotate-right"></i>
        </a>
      )}
      <a
        className="btn btn-secondary"
        title="edit"
        href={`/currently_inked/${id}/edit`}
      >
        <i className="fa fa-pencil" />
      </a>
      <a
        className="btn btn-secondary"
        title="archive"
        href={`/currently_inked/${id}/archive`}
        data-method="post"
      >
        <i className="fa fa-archive" />
      </a>
    </div>
  );
};

const UsageButton = ({ used, id }) => {
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
        onClick={() => setDisplayAsUsed(true)}
      >
        <i className="fa fa-bookmark"></i>
      </a>
    );
  }
};
