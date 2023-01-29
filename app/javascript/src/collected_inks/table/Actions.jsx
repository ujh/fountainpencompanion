import React from "react";

/**
 * @param {{ archive: boolean; preGlobalFilteredRows: any[]; setGlobalFilter: (val: string | undefined) => void; globalFilter?: string; }} props
 */
export const Actions = ({
  archive,
  preGlobalFilteredRows,
  setGlobalFilter,
  globalFilter
}) => {
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
            setGlobalFilter(e.target.value || undefined); // Set undefined to remove the filter entirely
          }}
          placeholder={`Type to search in ${preGlobalFilteredRows.length} inks`}
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
