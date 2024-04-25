import _ from "lodash";
import { fields } from "./fields";

export const groupedPens = (collectedPens) =>
  _.values(
    _.mapValues(
      _.groupBy(collectedPens, (pen) => fields.map((n) => pen[n]).join(",")),
      (pens) => pens[0]
    )
  );
