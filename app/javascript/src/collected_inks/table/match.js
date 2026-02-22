import { rankItem } from "@tanstack/match-sorter-utils";

/**
 * @param {any} row
 * @param {string} columnId
 * @param {string} filterValue
 * @returns {boolean}
 */
export function fuzzyMatch(row, columnId, filterValue) {
  if (!filterValue) return true;

  const attrs = ["brand_name", "line_name", "ink_name", "maker", "comment", "private_comment"];
  const tags = (row.original.tags || []).map((t) => t.name).join(" ");
  const clusterTags = (row.original.cluster_tags || []).join(" ");
  const searchText = `${attrs.map((a) => row.original[a] || "").join(" ")} ${tags} ${clusterTags}`;

  const itemRank = rankItem(searchText, filterValue);

  return itemRank.passed;
}
