import { matchSorter } from "match-sorter";

/**
 * @param {any[]} rows
 * @param {string} id
 * @param {string} filterValue
 * @returns {any[]}
 */
export function fuzzyMatch(rows, _, filterValue) {
  const attrs = [
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

  return matchSorter(rows, filterValue.replace(/\s+/gi, ""), {
    keys: [(row) => attrs.map((a) => row.values[a]).join("")]
  });
}
