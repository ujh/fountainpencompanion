import _ from "lodash";
import React, { useCallback, useState } from "react";
import { useFieldSwitcher } from "../../useFieldSwitcher";
import { LayoutToggle } from "../../components/LayoutToggle";
import { Switch } from "../../components/Switch";
import "./actions.scss";

/**
 * @param {{ archive: boolean; activeLayout: "card" | "table"; numberOfInks: number; hiddenFields: string[]; onHiddenFieldsChange: (newValues: string[]) => void; onFilterChange: (val: string | undefined) => void; onLayoutChange: (e: import('react').ChangeEvent) => void; }} props
 */
export const Actions = ({
  archive,
  activeLayout,
  numberOfInks,
  hiddenFields,
  onHiddenFieldsChange,
  onFilterChange,
  onLayoutChange
}) => {
  const [globalFilter, setGlobalFilter] = useState("");

  // The linter doesn't like our debounce call. We debounce
  // to not melt mountainofinks' phone when filtering :D
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const debouncedOnFilterChange = useCallback(
    _.debounce(
      (value) => {
        onFilterChange(value);
      },
      Math.min(numberOfInks / 10, 500)
    ),
    [onFilterChange, numberOfInks]
  );

  const { isSwitchedOn, onSwitchChange } = useFieldSwitcher(
    hiddenFields,
    onHiddenFieldsChange
  );

  return (
    <div>
      <div className="fpc-inks-actions">
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
                checked={isSwitchedOn("private")}
                onChange={(e) => onSwitchChange(e.target.checked, "private")}
              >
                Show&nbsp;private
              </Switch>
              <Switch
                checked={isSwitchedOn("maker")}
                onChange={(e) => onSwitchChange(e.target.checked, "maker")}
              >
                Show&nbsp;maker
              </Switch>
              <Switch
                checked={isSwitchedOn("kind")}
                onChange={(e) => onSwitchChange(e.target.checked, "kind")}
              >
                Show&nbsp;type
              </Switch>
              <Switch
                checked={isSwitchedOn("swabbed")}
                onChange={(e) => onSwitchChange(e.target.checked, "swabbed")}
              >
                Show&nbsp;swabbed
              </Switch>
              <Switch
                checked={isSwitchedOn("used")}
                onChange={(e) => onSwitchChange(e.target.checked, "used")}
              >
                Show&nbsp;used
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
              <Switch
                checked={isSwitchedOn("comment")}
                onChange={(e) => onSwitchChange(e.target.checked, "comment")}
              >
                Show&nbsp;comment
              </Switch>
              <Switch
                checked={isSwitchedOn("private_comment")}
                onChange={(e) =>
                  onSwitchChange(e.target.checked, "private_comment")
                }
              >
                Show&nbsp;private&nbsp;comment
              </Switch>
              <Switch
                checked={isSwitchedOn("tags")}
                onChange={(e) => onSwitchChange(e.target.checked, "tags")}
              >
                Show&nbsp;tags
              </Switch>
              <Switch
                checked={isSwitchedOn("cluster_tags")}
                onChange={(e) =>
                  onSwitchChange(e.target.checked, "cluster_tags")
                }
              >
                Show&nbsp;cluster&nbsp;tags
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
        {!archive && (
          <>
            <a className="btn btn-sm btn-link" href="/collected_inks/import">
              Import
            </a>
            <a className="btn btn-sm btn-link" href="/collected_inks.csv">
              Export
            </a>
            <a
              className="btn btn-sm btn-link"
              href="/collected_inks?search[archive]=true"
            >
              Archive
            </a>
          </>
        )}
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
              placeholder={`Type to search in ${numberOfInks} inks`}
              aria-label="Search"
            />
          </div>
          {!archive && (
            <a className="ms-2 btn btn-success" href="/collected_inks/new">
              Add&nbsp;ink
            </a>
          )}
        </div>
      </div>
    </div>
  );
};
