import _ from "lodash";
import React, { useCallback, useState } from "react";
import { LayoutToggle } from "../../components/LayoutToggle";
import { Switch } from "../../components/Switch";
import "./actions.scss";

/**
 * @param {{ activeLayout: "card" | "table"; numberOfEntries: number; hiddenFields: string[]; onHiddenFieldsChange: (newValues: string[]) => void; onFilterChange: (val: string | undefined) => void; onLayoutChange: (e: import('react').ChangeEvent) => void; }} props
 */
export const Actions = ({
  activeLayout,
  numberOfEntries,
  hiddenFields,
  onHiddenFieldsChange,
  onFilterChange,
  onLayoutChange
}) => {
  const [globalFilter, setGlobalFilter] = useState("");

  // The linter doesn't like our debounce call
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const debouncedOnFilterChange = useCallback(
    _.debounce((value) => {
      onFilterChange(value);
    }, Math.min(numberOfEntries / 10, 500)),
    [onFilterChange, numberOfEntries]
  );

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

  return (
    <div>
      <div className="fpc-currently-inked-actions">
        <LayoutToggle activeLayout={activeLayout} onChange={onLayoutChange} />
        <div className="dropdown">
          <button
            type="button"
            title="Configure visible fields"
            className="btn btn-sm btn-outline-secondary dropdown-toggle"
            data-bs-toggle="dropdown"
            aria-expanded="false"
            data-bs-auto-close="outside"
          >
            <i className="fa fa-cog"></i>
          </button>
          <form className="dropdown-menu p-4">
            <div className="mb-2">
              <Switch
                checked={isSwitchedOn("comment")}
                onChange={(e) => onSwitchChange(e.target.checked, "comment")}
              >
                Show&nbsp;comment
              </Switch>
              <Switch
                checked={isSwitchedOn("pen_name")}
                onChange={(e) => onSwitchChange(e.target.checked, "pen_name")}
              >
                Show&nbsp;pen
              </Switch>
              <Switch
                checked={isSwitchedOn("inked_on")}
                onChange={(e) => onSwitchChange(e.target.checked, "inked_on")}
              >
                Show&nbsp;date&nbsp;inked
              </Switch>
              <Switch
                checked={isSwitchedOn("last_used_on")}
                onChange={(e) =>
                  onSwitchChange(e.target.checked, "last_used_on")
                }
              >
                Show&nbsp;last&nbsp;used
              </Switch>
            </div>
            <button
              type="button"
              className="btn btn-sm btn-link p-0 mt-2"
              onClick={() => onHiddenFieldsChange(null)}
            >
              Restore defaults
            </button>
          </form>
        </div>
      </div>
      <div className="d-flex flex-wrap justify-content-end align-items-center mb-3">
        <a className="btn btn-sm btn-link" href="/currently_inked.csv">
          Export
        </a>
        <a className="btn btn-sm btn-link" href="/usage_records">
          Usage
        </a>
        <a className="btn btn-sm btn-link" href="/currently_inked_archive">
          Archive
        </a>
        <div className="m-2 d-flex">
          <div className="search" style={{ minWidth: "190px" }}>
            <input
              className="form-control"
              type="text"
              value={globalFilter || ""}
              onChange={(e) => {
                const nextValue = e.target.value || undefined; // Set undefined to remove the filter entirely
                setGlobalFilter(nextValue);
                debouncedOnFilterChange(nextValue);
              }}
              placeholder={`Type to search in ${numberOfEntries} entries`}
              aria-label="Search"
            />
          </div>
          <a className="ms-2 btn btn-success" href="/currently_inked/new">
            Add&nbsp;entry
          </a>
        </div>
      </div>
    </div>
  );
};
