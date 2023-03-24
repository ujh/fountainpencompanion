import React from "react";
import { ArchiveButton, EditButton, DeleteButton } from "../components";

/**
 * @typedef {"bottle" | "sample" | "cartridge" | "swab"} InkType
 * @param {{ id: string; archived: boolean; brand_name: string; line_name?: string; ink_name: string; kind?: InkType; }} props
 */
export const ActionsCell = ({
  id,
  archived,
  brand_name,
  line_name,
  ink_name,
  kind
}) => {
  let inkName = [brand_name, line_name, ink_name].filter((c) => c).join(" ");
  if (kind) inkName += ` - ${kind}`;
  return (
    <div className="actions">
      <EditButton name={inkName} id={id} archived={archived} />
      <ArchiveButton name={inkName} id={id} archived={archived} />
      <DeleteButton name={inkName} id={id} archived={archived} />
    </div>
  );
};
