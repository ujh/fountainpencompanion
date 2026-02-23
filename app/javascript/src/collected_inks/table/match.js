import { rankItem } from "@tanstack/match-sorter-utils";

const allAttrs = ["brand_name", "line_name", "ink_name", "maker", "comment", "private_comment"];

/**
 * Creates a fuzzy match filter function that only searches visible fields.
 * @param {string[]} hiddenFields - field names to exclude from search
 * @returns {(row: any, columnId: string, filterValue: string) => boolean}
 */
export function createFuzzyMatch(hiddenFields = []) {
  const attrs = allAttrs.filter((a) => !hiddenFields.includes(a));
  const includeTags = !hiddenFields.includes("tags");
  const includeClusterTags = !hiddenFields.includes("cluster_tags");

  return function fuzzyMatch(row, columnId, filterValue) {
    if (!filterValue) return true;

    const tags = includeTags ? (row.original.tags || []).map((t) => t.name).join(" ") : "";
    const clusterTags = includeClusterTags ? (row.original.cluster_tags || []).join(" ") : "";
    const searchText = `${attrs.map((a) => row.original[a] || "").join(" ")} ${tags} ${clusterTags}`;

    const itemRank = rankItem(searchText, filterValue);

    return itemRank.passed;
  };
}

/**
 * Default fuzzy match filter with no hidden fields, for backward compatibility.
 * @param {any} row
 * @param {string} columnId
 * @param {string} filterValue
 * @returns {boolean}
 */
export const fuzzyMatch = createFuzzyMatch();
