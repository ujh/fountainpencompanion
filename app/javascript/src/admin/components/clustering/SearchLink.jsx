import React from "react";
export const SearchLink = ({ ci, fields }) => {
  const fullName = fields.map((a) => ci[a]).join(" ");
  return (
    <a
      href={`https://google.com/search?q=${encodeURIComponent(fullName)}`}
      target="_blank"
      rel="noreferrer"
    >
      <i className="fa fa-external-link"></i>
    </a>
  );
};
