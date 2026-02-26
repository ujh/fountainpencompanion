import { matchSorter } from "match-sorter";

/**
 * @param {any[]} rows
 * @param {string | undefined} filterValue
 * @param {string[]} hiddenFields
 * @returns {any[]}
 */
export function fuzzyMatch(rows, filterValue, hiddenFields = []) {
  if (!filterValue) {
    return rows;
  }

  const attrs = ["pen_name", "ink_name", "comment"].filter((a) => !hiddenFields.includes(a));

  return matchSorter(rows, filterValue.replace(/\s+/gi, ""), {
    keys: [(row) => attrs.map((a) => row[a]).join("")]
  });
}
