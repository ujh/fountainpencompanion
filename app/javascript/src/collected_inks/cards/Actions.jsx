import _ from "lodash";
import React, { useCallback, useState } from "react";

/**
 * @param {{ archive: boolean; numberOfInks: number; onFilterChange: (val: string | undefined) => void; }} props
 */
export const Actions = ({ archive, numberOfInks, onFilterChange }) => {
  const [globalFilter, setGlobalFilter] = useState("");

  // The linter doesn't like our debounce call. We debounce
  // to not melt mountainofinks' phone when filtering :D
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const debouncedOnFilterChange = useCallback(
    _.debounce((value) => {
      onFilterChange(value);
    }, Math.min(numberOfInks / 10, 500)),
    [onFilterChange, numberOfInks]
  );

  return (
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
      <div className="m-2 search" style={{ minWidth: "190px" }}>
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
        <>
          <a className="btn btn-success" href="/collected_inks/new">
            Add ink
          </a>
        </>
      )}
    </div>
  );
};
