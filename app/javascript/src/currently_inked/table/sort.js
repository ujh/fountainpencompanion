import { colorSort as genericColorSort } from "../../color-sorting";

export const colorSort = (rowA, rowB, columnId) =>
  genericColorSort(rowA.values[columnId], rowB.values[columnId]);
