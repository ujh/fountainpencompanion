import React, { useMemo, useState } from "react";
import { useHiddenFields } from "../../useHiddenFields";
import { Actions } from "../components/Actions";
import { Cards } from "./Cards";
import { fuzzyMatch } from "./match";

export const storageKeyHiddenFields = "fpc-collected-pens-cards-hidden-fields";

export const CollectedPensCards = ({ pens, onLayoutChange }) => {
  const [matchOn, setMatchOn] = useState("");
  const visible = fuzzyMatch(pens, matchOn);

  const defaultHiddenFields = useMemo(() => {
    let hideIfNoneWithValue = [
      "nib",
      "color",
      "comment",
      "usage",
      "daily_usage",
      "last_used_on",
      "material",
      "price",
      "trim_color",
      "filling_system"
    ].filter((n) => !pens.some((e) => e[n]));
    return hideIfNoneWithValue;
  }, [pens]);

  const { hiddenFields, onHiddenFieldsChange } = useHiddenFields(
    storageKeyHiddenFields,
    defaultHiddenFields
  );

  return (
    <div data-testid="card-layout">
      <Actions
        activeLayout="card"
        numberOfPens={pens.length}
        onFilterChange={setMatchOn}
        onLayoutChange={onLayoutChange}
        hiddenFields={hiddenFields}
        onHiddenFieldsChange={onHiddenFieldsChange}
      />
      <Cards data={visible} hiddenFields={hiddenFields} />
    </div>
  );
};
