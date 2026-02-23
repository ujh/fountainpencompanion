const getRowValue = (row, columnId) => {
  if (row?.getValue) return row.getValue(columnId);
  if (row?.values) return row.values[columnId];
  return undefined;
};

export const dateSort = (rowA, rowB, columnId) => {
  const valueA = getRowValue(rowA, columnId);
  const valueB = getRowValue(rowB, columnId);

  // Handle null/undefined values - they should always be at the end
  if (!valueA && !valueB) return 0;
  if (!valueA) return 1; // valueA is null, put it after valueB
  if (!valueB) return -1; // valueB is null, put it before valueA

  // Both have values, compare them (ascending order, library handles desc)
  const dateA = new Date(valueA);
  const dateB = new Date(valueB);

  if (dateA < dateB) return -1;
  if (dateA > dateB) return 1;
  return 0;
};
