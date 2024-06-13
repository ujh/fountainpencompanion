import _ from "lodash";
import { fields } from "./fields";

export const groupedPens = (modelVariants) =>
  _.values(
    _.mapValues(
      _.groupBy(modelVariants, (mv) => fields.map((n) => mv[n]).join(",")),
      (mvs) => mvs[0]
    )
  );
