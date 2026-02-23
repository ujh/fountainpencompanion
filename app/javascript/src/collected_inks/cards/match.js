import { matchSorter } from "match-sorter";

const allAttrs = ["brand_name", "line_name", "ink_name", "maker", "comment", "private_comment"];

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

  const attrs = allAttrs.filter((a) => !hiddenFields.includes(a));
  const includeTags = !hiddenFields.includes("tags");
  const includeClusterTags = !hiddenFields.includes("cluster_tags");

  return matchSorter(rows, filterValue.replace(/\s+/gi, ""), {
    keys: [
      (row) => {
        const v = attrs.map((a) => row[a]).join(" ");
        const tags = includeTags ? (row.tags || []).map((t) => t.name).join(" ") : "";
        const clusterTags = includeClusterTags ? (row.cluster_tags || []).join(" ") : "";
        return [v, tags, clusterTags].join(" ");
      }
    ]
  });
}
