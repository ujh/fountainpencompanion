import React from "react";
import _ from "lodash";

export const DisplayMicroCluster = ({ data, children }) => {
  return (
    <table className="table">
      <thead>
        <tr>
          <th></th>
          <th>{data.attributes.simplified_brand_name}</th>
          <th>{data.attributes.simplified_line_name}</th>
          <th>{data.attributes.simplified_ink_name}</th>
          <th></th>
          <th></th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <CollectedInksList collectedInks={data.collected_inks} />
        {children}
      </tbody>
    </table>
  );
};

export const CollectedInksList = ({ collectedInks }) => {
  const grouped = _.groupBy(collectedInks, ci =>
    ["brand_name", "line_name", "ink_name"].map(n => ci.attributes[n]).join("")
  );
  const sorted = _.reverse(_.sortBy(_.values(grouped), "length")).map(a => ({
    count: a.length,
    ci: a[0]
  }));
  return sorted.map(({ count, ci }) => {
    return (
      <tr key={ci.id}>
        <td>{count}</td>
        <td>{ci.attributes.brand_name}</td>
        <td>{ci.attributes.line_name}</td>
        <td>{ci.attributes.ink_name}</td>
        <td>{ci.attributes.maker}</td>
        <td
          style={{
            backgroundColor: ci.attributes.color,
            width: "30px"
          }}
        ></td>
        <td>
          <SearchLink ci={ci} />
        </td>
      </tr>
    );
  });
};

const SearchLink = ({ ci }) => {
  const fullName = ["brand_name", "line_name", "ink_name"]
    .map(a => ci.attributes[a])
    .join(" ");
  return (
    <a
      href={`https://google.com/search?q=${encodeURIComponent(fullName)}`}
      target="_blank"
    >
      <i className="fa fa-external-link"></i>
    </a>
  );
};
