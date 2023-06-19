import { useCallback } from "react";

export const useFieldSwitcher = (hiddenFields, onHiddenFieldsChange) => {
  const isSwitchedOn = useCallback(
    (field) => !hiddenFields.includes(field),
    [hiddenFields]
  );

  const onSwitchChange = useCallback(
    (checked, field) => {
      if (checked) {
        const newHiddenFields = hiddenFields.filter((f) => f !== field);
        onHiddenFieldsChange(newHiddenFields);
      } else {
        const newHiddenFields = [...hiddenFields, field];
        onHiddenFieldsChange(newHiddenFields);
      }
    },
    [hiddenFields, onHiddenFieldsChange]
  );

  return {
    isSwitchedOn,
    onSwitchChange
  };
};
