import React from "react";
import _ from "lodash";
import { SearchLink } from "./SearchLink";

export const EntriesList = ({ entries, fields, extra }) => {
  const grouped = _.groupBy(entries, (e) => fields.map((n) => e[n]).join(","));
  const sorted = _.reverse(_.sortBy(_.values(grouped), "length")).map((a) => ({
    count: a.length,
    e: a[0]
  }));
  return sorted.map(({ count, e }) => {
    return (
      <tr key={e.id}>
        <td>{count}</td>
        {fields.map((field) => (
          <td key={field}>{e[field]}</td>
        ))}
        <td>{extra && extra(e)}</td>
        <td>
          <SearchLink e={e} fields={fields} />
        </td>
        <td></td>
      </tr>
    );
  });
};
