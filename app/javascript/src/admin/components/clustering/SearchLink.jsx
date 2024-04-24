import React from "react";
export const SearchLink = ({ e, fields }) => {
  const fullName = fields.map((a) => e[a]).join(" ");
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
