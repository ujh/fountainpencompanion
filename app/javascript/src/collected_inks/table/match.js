import { rankItem } from "@tanstack/match-sorter-utils";

const allAttrs = ["brand_name", "line_name", "ink_name", "maker", "comment", "private_comment"];

/**
 * Global filter function that accepts a composite filterValue containing both
 * the search text and the list of hidden fields. This avoids closure-based
 * memoization issues: because the filterValue itself changes when hiddenFields
 * change, TanStack Table's internal memo correctly re-runs the filter.
 *
 * @param {any} row - TanStack Table row object
 * @param {string} columnId - column identifier (unused, required by TanStack API)
 * @param {string | { text: string, hiddenFields: string[] }} filterValue -
 *   Either a plain string (backward compat) or a composite object with `text`
 *   and `hiddenFields`.
 * @returns {boolean}
 */
export function fuzzyFilter(row, columnId, filterValue) {
  let text;
  let hiddenFields;

  if (filterValue && typeof filterValue === "object") {
    text = filterValue.text;
    hiddenFields = filterValue.hiddenFields || [];
  } else {
    text = filterValue;
    hiddenFields = [];
  }

  if (!text) return true;

  const attrs = allAttrs.filter((a) => !hiddenFields.includes(a));
  const includeTags = !hiddenFields.includes("tags");
  const includeClusterTags = !hiddenFields.includes("cluster_tags");

  const tags = includeTags ? (row.original.tags || []).map((t) => t.name).join(" ") : "";
  const clusterTags = includeClusterTags ? (row.original.cluster_tags || []).join(" ") : "";
  const searchText = `${attrs.map((a) => row.original[a] || "").join(" ")} ${tags} ${clusterTags}`;

  const itemRank = rankItem(searchText, text);

  return itemRank.passed;
}

/**
 * Creates a fuzzy match filter function that only searches visible fields.
 * @param {string[]} hiddenFields - field names to exclude from search
 * @returns {(row: any, columnId: string, filterValue: string) => boolean}
 * @deprecated Use fuzzyFilter with composite filterValue instead
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
