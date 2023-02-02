import React from "react";

/**
 * @param {{ name: string; id: string; archived: boolean }} props
 */
export const EditButton = ({ className, name, id, archived }) => {
  let href = `/collected_inks/${id}/edit`;
  if (archived) href += "?search[archive]=true";
  return (
    <span className={className}>
      <a className="btn btn-secondary" href={href} title={`Edit ${name}`}>
        <i className="fa fa-pencil" />
      </a>
    </span>
  );
};
