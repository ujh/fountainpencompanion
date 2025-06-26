import levenshtein from "fast-levenshtein";

// This is the most expensive computation in this app. Group inks by name first
// and only compare between those that are really different.
export const withDistance = (macroClusters, activeCluster) => {
  const activeGroupedInks = activeCluster.grouped_entries;
  return macroClusters.map((c) => {
    const macroClusterInks = c.grouped_entries.concat(c);
    return {
      ...c,
      distance: dist(macroClusterInks, activeGroupedInks)
    };
  });
};

const dist = (macroClusterInks, microClusterInks) => {
  const calc1 = (c1, c2) => minLev(c1.brand, c2.brand) + minLev(c1.model, c2.model);
  const calc2 = (c1, c2) => minLev([c1.brand, c1.model].join(""), [c2.brand, c2.model].join(""));
  const calc3 = (c1, c2) => minLev(c1.brand, c2.brand) + minLev(c1.model, c2.model);

  let minDistance = Number.MAX_SAFE_INTEGER;
  macroClusterInks.forEach((ci1) => {
    microClusterInks.forEach((ci2) => {
      const dist = Math.min(...[calc1(ci1, ci2), calc2(ci1, ci2), calc3(ci1, ci2)]);
      if (dist < minDistance) minDistance = dist;
    });
  });
  return minDistance;
};

const minLev = (str1, str2) => {
  const safeStr1 = str1 || "";
  const safeStr2 = str2 || "";
  return Math.min(
    levenshtein.get(safeStr1, safeStr2),
    levenshtein.get(stripped(safeStr1), stripped(safeStr2))
  );
};

const stripped = (str) => {
  if (!str) return "";
  return str
    .replace(/-/i, "")
    .replace(/(\([^)]*\))/i, "")
    .replace(/\s+/i, "");
};
