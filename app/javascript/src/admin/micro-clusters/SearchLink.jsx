import React from "react";
export const SearchLink = ({ ci }) => {
  const fullName = ["brand_name", "line_name", "ink_name"]
    .map((a) => ci[a])
    .join(" ");
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
