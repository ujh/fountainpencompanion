import { rankItem } from "@tanstack/match-sorter-utils";

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
 * @param {any} row
 * @param {string} columnId
 * @param {{ filterValue?: string, hiddenFields?: string[] }} compositeFilter
 * @param {Function} addMeta
 * @returns {boolean}
 */
export function fuzzyMatch(row, columnId, compositeFilter, addMeta) {
  const filterValue = compositeFilter?.filterValue ?? "";
  const hiddenFields = compositeFilter?.hiddenFields ?? [];

  if (!filterValue) {
    addMeta({ itemRank: { passed: true } });
    return true;
  }

  const attrs = ALL_ATTRS.filter((a) => !hiddenFields.includes(a));

  const searchText = attrs.map((a) => row.original[a] || "").join(" ");

  const itemRank = rankItem(searchText, filterValue);

  addMeta({ itemRank });

  return itemRank.passed;
}
