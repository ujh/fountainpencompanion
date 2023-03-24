import React from "react";

/**
 * @param {{ name: string; id: string; archived: boolean }} props
 */
export const ArchiveButton = ({ className, name, id, archived }) => {
  if (archived) {
    return (
      <span className={className}>
        <a
          className="btn btn-secondary"
          title={`Unarchive ${name}`}
          href={`/collected_inks/${id}/unarchive`}
          data-method="post"
        >
          <i className="fa fa-folder-open" />
        </a>
      </span>
    );
  } else {
    return (
      <span className={className}>
        <a
          className="btn btn-secondary"
          title={`Archive ${name}`}
          href={`/collected_inks/${id}/archive`}
          data-method="post"
        >
          <i className="fa fa-archive" />
        </a>
      </span>
    );
  }
};
