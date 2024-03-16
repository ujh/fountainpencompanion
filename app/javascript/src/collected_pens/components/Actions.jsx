import _ from "lodash";
import React, { useCallback, useState } from "react";
import { useFieldSwitcher } from "../../useFieldSwitcher";
import { LayoutToggle } from "../../components/LayoutToggle";
import { Switch } from "../../components/Switch";
import "./actions.scss";

/**
 * @param {{ activeLayout: "card" | "table"; numberOfPens: number; hiddenFields: string[]; onHiddenFieldsChange: (newValues: string[]) => void; onFilterChange: (val: string | undefined) => void; onLayoutChange: (e: import('react').ChangeEvent) => void; }} props
 */
export const Actions = ({
  activeLayout,
  numberOfPens,
  hiddenFields,
  onHiddenFieldsChange,
  onFilterChange,
  onLayoutChange
}) => {
  const [globalFilter, setGlobalFilter] = useState("");

  // The linter doesn't like our debounce call
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const debouncedOnFilterChange = useCallback(
    _.debounce(
      (value) => {
        onFilterChange(value);
      },
      Math.min(numberOfPens / 10, 500)
    ),
    [onFilterChange, numberOfPens]
  );

  const { isSwitchedOn, onSwitchChange } = useFieldSwitcher(
    hiddenFields,
    onHiddenFieldsChange
  );

  return (
    <div>
      <div className="fpc-pens-actions">
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
                checked={isSwitchedOn("nib")}
                onChange={(e) => onSwitchChange(e.target.checked, "nib")}
              >
                Show&nbsp;nib
              </Switch>
              <Switch
                checked={isSwitchedOn("color")}
                onChange={(e) => onSwitchChange(e.target.checked, "color")}
              >
                Show&nbsp;color
              </Switch>
              <Switch
                checked={isSwitchedOn("material")}
                onChange={(e) => onSwitchChange(e.target.checked, "material")}
              >
                Show&nbsp;material
              </Switch>
              <Switch
                checked={isSwitchedOn("trim_color")}
                onChange={(e) => onSwitchChange(e.target.checked, "trim_color")}
              >
                Show&nbsp;trim&nbsp;color
              </Switch>
              <Switch
                checked={isSwitchedOn("filling_system")}
                onChange={(e) =>
                  onSwitchChange(e.target.checked, "filling_system")
                }
              >
                Show&nbsp;filling&nbsp;system
              </Switch>
              <Switch
                checked={isSwitchedOn("price")}
                onChange={(e) => onSwitchChange(e.target.checked, "price")}
              >
                Show&nbsp;price
              </Switch>
              <Switch
                checked={isSwitchedOn("comment")}
                onChange={(e) => onSwitchChange(e.target.checked, "comment")}
              >
                Show&nbsp;comment
              </Switch>
              <Switch
                checked={isSwitchedOn("usage")}
                onChange={(e) => onSwitchChange(e.target.checked, "usage")}
              >
                Show&nbsp;usage
              </Switch>
              <Switch
                checked={isSwitchedOn("daily_usage")}
                onChange={(e) =>
                  onSwitchChange(e.target.checked, "daily_usage")
                }
              >
                Show&nbsp;daily&nbsp;usage
              </Switch>
              <Switch
                checked={isSwitchedOn("last_used_on")}
                onChange={(e) =>
                  onSwitchChange(e.target.checked, "last_used_on")
                }
              >
                Show&nbsp;last&nbsp;usage
              </Switch>
              <Switch
                checked={isSwitchedOn("created_at")}
                onChange={(e) => onSwitchChange(e.target.checked, "created_at")}
              >
                Show&nbsp;Added&nbsp;On
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
        <>
          <a className="btn btn-sm btn-link" href="/collected_pens/import">
            Import
          </a>
          <a className="btn btn-sm btn-link" href="/collected_pens.csv">
            Export
          </a>
          <a className="btn btn-sm btn-link" href="/collected_pens_archive">
            Archive
          </a>
        </>
        <div className="m-2 d-flex">
          <div className="search" style={{ minWidth: "205px" }}>
            <input
              className="form-control"
              type="text"
              value={globalFilter || ""}
              onChange={(e) => {
                const nextValue = e.target.value || undefined; // Set undefined to remove the filter entirely
                setGlobalFilter(nextValue);
                debouncedOnFilterChange(nextValue);
              }}
              placeholder={`Type to search in ${numberOfPens} pens`}
              aria-label="Search"
            />
          </div>
          <a className="ms-2 btn btn-success" href="/collected_pens/new">
            Add&nbsp;pen
          </a>
        </div>
      </div>
    </div>
  );
};
