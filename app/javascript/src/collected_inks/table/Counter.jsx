import React from "react";

/**
 * @typedef {"bottle" | "sample" | "cartridge" | "swab"} InkType
 * @param {{ data: Record<InkType, number>; field: InkType }} props
 */
export const Counter = ({ data, field }) => {
  const value = data[field];
  if (!value) return null;

  return (
    <>
      <span className="counter">
        {value}x {field}
      </span>
      <br />
    </>
  );
};
