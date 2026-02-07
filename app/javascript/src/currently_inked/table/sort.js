import { colorSort as genericColorSort } from "../../color-sorting";

const getRowValue = (row, columnId) => {
  if (row?.getValue) return row.getValue(columnId);
  if (row?.values) return row.values[columnId];
  return undefined;
};

export const colorSort = (rowA, rowB, columnId) =>
  genericColorSort(getRowValue(rowA, columnId), getRowValue(rowB, columnId));
