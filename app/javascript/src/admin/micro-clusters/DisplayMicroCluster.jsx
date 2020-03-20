import React from "react";
import _ from "lodash";

export const DisplayMicroCluster = ({ data }) => {
  const grouped = _.groupBy(data.collected_inks, ci =>
    ["brand_name", "line_name", "ink_name"].map(n => ci.attributes[n]).join("")
  );
  return (
    <div>
      <table className="table table-striped">
        <thead>
          <tr>
            <th></th>
            <th>{data.attributes.simplified_brand_name}</th>
            <th>{data.attributes.simplified_line_name}</th>
            <th>{data.attributes.simplified_ink_name}</th>
            <th></th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {_.values(grouped).map(cis => {
            const ci = cis[0];
            const count = cis.length;
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
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};
