import React from "react";

export const ActionsCell = ({ id }) => {
  return (
    <div className="actions">
      <a
        className="btn btn-secondary"
        title="edit"
        href={`/collected_pens/${id}/edit`}
      >
        <i className="fa fa-pencil" />
      </a>
      <a
        className="btn btn-secondary"
        title="archive"
        href={`/collected_pens/${id}/archive`}
        data-method="post"
      >
        <i className="fa fa-archive" />
      </a>
    </div>
  );
};
