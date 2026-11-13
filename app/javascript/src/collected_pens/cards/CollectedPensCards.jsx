import { useMemo } from "react";
import { useHiddenFields } from "../../useHiddenFields";
import { useSearchParamState } from "../../useUrlState";
import { Actions } from "../components/Actions";
import { fuzzyMatch } from "../match";
import { Cards } from "./Cards";

export const storageKeyHiddenFields = "fpc-collected-pens-cards-hidden-fields";

export const CollectedPensCards = ({ pens, onLayoutChange }) => {
  const [matchOn, setMatchOn] = useSearchParamState("q");

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

  const visible = fuzzyMatch(pens, matchOn, hiddenFields);

  return (
    <div data-testid="card-layout">
      <Actions
        activeLayout="card"
        numberOfPens={pens.length}
        initialFilter={matchOn}
        onFilterChange={setMatchOn}
        onLayoutChange={onLayoutChange}
        hiddenFields={hiddenFields}
        onHiddenFieldsChange={onHiddenFieldsChange}
      />
      <Cards data={visible} hiddenFields={hiddenFields} />
    </div>
  );
};
