import { colorSort as genericColorSort } from "../../color-sorting";

export const booleanSort = (rowA, rowB, columnId) => {
  if (rowA.values[columnId] == rowB.values[columnId]) return 0;
  if (rowA.values[columnId] && !rowB.values[columnId]) return 1;
  return -1;
};

export const colorSort = (rowA, rowB, columnId) =>
  genericColorSort(rowA.values[columnId], rowB.values[columnId]);
