/**
 * @param {any} row
 * @param {string} columnId
 * @param {string} filterValue
 * @returns {boolean}
 */
export function fuzzyMatch(row, columnId, filterValue) {
  if (!filterValue) return true;

  const attrs = ["ink_name", "pen_name", "comment"];
  const searchText = attrs.map((a) => row.original[a] || "").join(" ");
  const normalizedFilter = filterValue.replace(/\s+/gi, "").toLowerCase();
  const normalizedText = searchText.replace(/\s+/gi, "").toLowerCase();

  return normalizedText.includes(normalizedFilter);
}
