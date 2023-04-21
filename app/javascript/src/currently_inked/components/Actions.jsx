import React from "react";

export const Actions = () => {
  return (
    <div>
      <div className="d-flex flex-wrap justify-content-end align-items-center mb-3">
        <>
          <a className="btn btn-sm btn-link" href="/currently_inked.csv">
            Export
          </a>
          <a className="btn btn-sm btn-link" href="/usage_records">
            Usage
          </a>
          <a className="btn btn-sm btn-link" href="/currently_inked_archive">
            Archive
          </a>
        </>
        <div className="m-2 d-flex">
          <a className="ms-2 btn btn-success" href="/currently_inked/new">
            Add&nbsp;entry
          </a>
        </div>
      </div>
    </div>
  );
};
