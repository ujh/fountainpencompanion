import _ from "lodash";

export const groupedInks = (collectedInks) =>
  _.values(
    _.mapValues(
      _.groupBy(collectedInks, (ci) =>
        ["brand_name", "line_name", "ink_name"].map((n) => ci[n]).join(",")
      ),
      (cis) => cis[0]
    )
  );
