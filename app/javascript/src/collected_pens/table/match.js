import { rankItem } from "@tanstack/match-sorter-utils";

/**
 * @param {any} row
 * @param {string} columnId
 * @param {string} filterValue
 * @param {Function} addMeta
 * @returns {boolean}
 */
export function fuzzyMatch(row, columnId, filterValue, addMeta) {
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

  const searchText = attrs.map((a) => row.original[a] || "").join(" ");

  const itemRank = rankItem(searchText, filterValue);

  addMeta({ itemRank });

  return itemRank.passed;
}
