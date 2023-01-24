import React from "react";
import _ from "lodash";
import { SearchLink } from "./SearchLink";
export const CollectedInksList = ({ collectedInks }) => {
  const grouped = _.groupBy(collectedInks, (ci) =>
    ["brand_name", "line_name", "ink_name"].map((n) => ci[n]).join(",")
  );
  const sorted = _.reverse(_.sortBy(_.values(grouped), "length")).map((a) => ({
    count: a.length,
    ci: a[0]
  }));
  return sorted.map(({ count, ci }) => {
    return (
      <tr key={ci.id}>
        <td>{count}</td>
        <td>{ci.brand_name}</td>
        <td>{ci.line_name}</td>
        <td>{ci.ink_name}</td>
        <td>{ci.maker}</td>
        <td>
          <div
            style={{
              backgroundColor: ci.color,
              height: "45px",
              width: "45px"
            }}
          />
        </td>
        <td>
          <SearchLink ci={ci} />
        </td>
        <td></td>
      </tr>
    );
  });
};
