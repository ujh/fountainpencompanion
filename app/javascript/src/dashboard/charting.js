import { interpolateBlues } from "d3-scale-chromatic";

// Assumes that the entries are already sorted
export const dataWithOtherEntry = ({ data, nameKey }) => {
  const globalCount = data.reduce((acc, { count }) => acc + count, 0);
  const cutOff = globalCount * 0.9;
  let currentCount = 0;
  let otherEntries = [];
  let dataWithOther = [];
  // This only works when the entries are ordered descending
  data.forEach((entry) => {
    if (currentCount > cutOff) {
      otherEntries.push(entry);
    } else {
      dataWithOther.push(entry);
      currentCount += entry.count;
    }
  });
  if (otherEntries.length < 2) {
    dataWithOther = dataWithOther.concat(otherEntries);
  } else {
    dataWithOther.push({
      [nameKey]: "Other",
      count: otherEntries.reduce((acc, { count }) => acc + count, 0)
    });
  }
  return dataWithOther;
};

export const generateColors = (amount) => {
  const step = 1.0 / amount;
  let colors = [];
  for (let i = 0; i < amount; i++) {
    colors.push(interpolateBlues(1 - i * step));
  }
  return colors;
};
