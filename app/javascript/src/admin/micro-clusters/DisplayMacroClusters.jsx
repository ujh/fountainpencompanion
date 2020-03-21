import React from "react";
import _ from "lodash";

export const DisplayMacroClusters = ({ data, microCluster }) => {
  return (
    <div>
      <table className="table table-striped">
        <thead>
          <tr>
            <th>Brand</th>
            <th>Line</th>
            <th>Ink</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <CreateRow key={microCluster.id} microCluster={microCluster} />
        </tbody>
      </table>
    </div>
  );
};

const CreateRow = ({ microCluster }) => {
  const grouped = _.groupBy(microCluster.collected_inks, ci =>
    ["brand_name", "line_name", "ink_name"].map(n => ci.attributes[n]).join("")
  );
  const ci = _.maxBy(_.values(grouped), array => array.length)[0];
  return (
    <tr>
      <td>
        <input
          type="text"
          name="brand_name"
          defaultValue={ci.attributes.brand_name}
        />
      </td>
      <td>
        <input
          type="text"
          name="line_name"
          defaultValue={ci.attributes.line_name}
        />
      </td>
      <td>
        <input
          type="text"
          name="ink_name"
          defaultValue={ci.attributes.ink_name}
        />
      </td>
      <td></td>
    </tr>
  );
};
