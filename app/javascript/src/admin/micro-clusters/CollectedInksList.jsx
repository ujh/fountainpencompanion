import React from "react";

import { EntriesList } from "../components/clustering/EntriesList";

export const CollectedInksList = ({ collectedInks }) => {
  const extra = (ci) => (
    <div
      style={{
        backgroundColor: ci.color,
        height: "45px",
        width: "45px"
      }}
    />
  );
  return (
    <EntriesList
      entries={collectedInks}
      fields={["brand_name", "line_name", "ink_name"]}
      extra={extra}
    />
  );
};
