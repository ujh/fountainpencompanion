import { useMemo } from "react";
import { ListStateContext } from "../../listState";
import { useHiddenFields } from "../../useHiddenFields";
import { useSearchParamState } from "../../useUrlState";
import { Actions } from "../components/Actions";
import { fuzzyMatch } from "../match";
import { Cards } from "./Cards";

export const storageKeyHiddenFields = "fpc-currently-inked-cards-hidden-fields";

export const CurrentlyInkedCards = ({ currentlyInked, onLayoutChange, onUsageRecorded }) => {
  const { hiddenFields, onHiddenFieldsChange } = useHiddenFields(storageKeyHiddenFields);
  const [matchOn, setMatchOn] = useSearchParamState("q");
  const [sort] = useSearchParamState("sort");
  const listState = useMemo(() => ({ q: matchOn, sort }), [matchOn, sort]);
  const visible = fuzzyMatch(currentlyInked, matchOn, hiddenFields);

  return (
    <ListStateContext value={listState}>
      <div data-testid="card-layout">
        <Actions
          activeLayout="card"
          numberOfEntries={currentlyInked.length}
          initialFilter={matchOn}
          onFilterChange={setMatchOn}
          onLayoutChange={onLayoutChange}
          hiddenFields={hiddenFields}
          onHiddenFieldsChange={onHiddenFieldsChange}
        />
        <Cards data={visible} hiddenFields={hiddenFields} onUsageRecorded={onUsageRecorded} />
      </div>
    </ListStateContext>
  );
};
