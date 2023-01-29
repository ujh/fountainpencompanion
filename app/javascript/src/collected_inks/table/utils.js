import { matchSorter } from "match-sorter";
import { colorSort as genericColorSort } from "../../color-sorting";

export const booleanSort = (rowA, rowB, columnId) => {
  if (rowA.values[columnId] == rowB.values[columnId]) return 0;
  if (rowA.values[columnId] && !rowB.values[columnId]) return 1;
  return -1;
};

export const colorSort = (rowA, rowB, columnId) =>
  genericColorSort(rowA.values[columnId], rowB.values[columnId]);

/**
 * @param {any[]} rows
 * @param {string} id
 * @param {string} filterValue
 * @returns {any[]}
 */
export function fuzzyMatch(rows, _, filterValue) {
  const attrs = [
    "brand_name",
    "line_name",
    "ink_name",
    "maker",
    "comment",
    "private_comment"
  ];
  return matchSorter(rows, filterValue.replace(/\s+/gi, ""), {
    keys: [(row) => attrs.map((a) => row.values[a]).join("")]
  });
}
