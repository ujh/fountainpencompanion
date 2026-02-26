import { matchSorter } from "match-sorter";

const ALL_ATTRS = [
  "brand",
  "model",
  "nib",
  "color",
  "material",
  "trim_color",
  "filling_system",
  "price",
  "comment"
];

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

  const attrs = ALL_ATTRS.filter((a) => !hiddenFields.includes(a));

  return matchSorter(rows, filterValue.replace(/\s+/gi, ""), {
    keys: [(row) => attrs.map((a) => row[a]).join("")]
  });
}
