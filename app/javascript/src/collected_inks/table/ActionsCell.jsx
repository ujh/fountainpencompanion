import React from "react";
import { ArchiveButton } from "./ArchiveButton";
import { EditButton } from "./EditButton";

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
    <td className="actions">
      <EditButton name={inkName} id={id} archived={archived} />
      <ArchiveButton name={inkName} id={id} archived={archived} />
    </td>
  );
};
