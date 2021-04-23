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
      count: otherEntries.reduce((acc, { count }) => acc + count, 0),
    });
  }
  return dataWithOther;
};

export const getRandomColor = () => {
  var letters = "0123456789ABCDEF";
  var color = "#";
  for (var i = 0; i < 6; i++) {
    color += letters[Math.floor(Math.random() * 16)];
  }
  return color;
};
