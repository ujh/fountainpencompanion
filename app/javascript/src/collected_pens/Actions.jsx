import React from "react";

export const Actions = () => {
  return (
    <div className="d-flex justify-content-end align-items-center mb-3">
      <a className="btn btn-sm btn-link" href="/collected_pens/import">
        Import
      </a>
      <a className="btn btn-sm btn-link" href="/collected_pens.csv">
        Export
      </a>
      <a className="btn btn-sm btn-link me-2" href="/collected_pens_archive">
        Archive
      </a>
      <a className="btn btn-success" href="/collected_pens/new">
        Add pen
      </a>
    </div>
  );
};
