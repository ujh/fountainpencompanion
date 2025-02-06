import React from "react";

/**
 * @param {{ activeLayout: "card" | "table"; onChange: (e: import('react').ChangeEvent) => void; }} props
 */
export const LayoutToggle = ({ activeLayout, onChange }) => {
  return (
    <div className="btn-group btn-group-sm" role="group" aria-label="Choose layout">
      <input
        type="radio"
        className="btn-check"
        name="layout"
        id="layout-table"
        autoComplete="off"
        value="table"
        checked={activeLayout === "table"}
        onChange={onChange}
      />
      <label className="btn btn-outline-secondary" htmlFor="layout-table" title="Table layout">
        <i className="fa fa-table" aria-hidden="true" />
      </label>

      <input
        type="radio"
        className="btn-check"
        name="btnradio"
        id="layout-card"
        autoComplete="off"
        onChange={onChange}
        value="card"
        checked={activeLayout === "card"}
      />
      <label className="btn btn-outline-secondary" htmlFor="layout-card" title="Card layout">
        <i className="fa fa-square-o" aria-hidden="true" />
      </label>
    </div>
  );
};
