import { useHiddenFields } from "../../useHiddenFields";
import { useSearchParamState } from "../../useUrlState";
import { Actions } from "../components";
import { fuzzyMatch } from "../match";
import { Cards } from "./Cards";

export const storageKeyHiddenFields = "fpc-collected-inks-cards-hidden-fields";

export const CollectedInksCards = ({ data, archive, onLayoutChange }) => {
  const { hiddenFields, onHiddenFieldsChange } = useHiddenFields(storageKeyHiddenFields);
  const [matchOn, setMatchOn] = useSearchParamState("q");
  const visible = fuzzyMatch(data, matchOn, hiddenFields);

  return (
    <div>
      <Actions
        archive={archive}
        activeLayout="card"
        numberOfInks={data.length}
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
