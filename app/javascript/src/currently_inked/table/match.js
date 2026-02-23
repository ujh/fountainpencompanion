import { rankItem } from "@tanstack/match-sorter-utils";

const ALL_ATTRS = ["ink_name", "pen_name", "comment"];

/**
 * Fuzzy match filter function for TanStack Table that respects hidden fields.
 *
 * Accepts a structured filterValue of { text, hiddenFields } so that changes
 * to hiddenFields cause TanStack Table's memoized getFilteredRowModel to
 * invalidate and re-run the filter.
 *
 * @param {any} row
 * @param {string} columnId
 * @param {string | { text: string, hiddenFields?: string[] }} filterValue
 * @param {Function} addMeta
 * @returns {boolean}
 */
export function fuzzyMatch(row, columnId, filterValue, addMeta) {
  let text;
  let hiddenFields;

  if (typeof filterValue === "object" && filterValue !== null) {
    text = filterValue.text;
    hiddenFields = filterValue.hiddenFields || [];
  } else {
    text = filterValue;
    hiddenFields = [];
  }

  const attrs = ALL_ATTRS.filter((a) => !hiddenFields.includes(a));
  const searchText = attrs.map((a) => row.original[a] || "").join(" ");

  const itemRank = rankItem(searchText, text);

  addMeta({ itemRank });

  return itemRank.passed;
}
