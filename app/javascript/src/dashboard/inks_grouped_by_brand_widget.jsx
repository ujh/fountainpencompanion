import React from "react";
import { useContext } from "react";
import { Pie, PieChart, Tooltip, Cell } from "recharts";
import { Widget, WidgetDataContext, WidgetWidthContext } from "./widgets";

export const InksGroupedByBrandWidget = () => (
  <Widget
    header={<a href="/collected_inks">Inks</a>}
    path="/dashboard/widgets/inks_grouped_by_brand.json"
  >
    <InksGroupedByBrandWidgetContent />
  </Widget>
);

const InksGroupedByBrandWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const width = useContext(WidgetWidthContext);
  const brands = data.attributes.brands;
  return (
    <>
      <p>Your inks grouped by brand</p>
      <PieChart width={width} height={width}>
        <Pie
          data={dataWithOtherEntry({ data: brands, nameKey: "brand_name" })}
          dataKey="count"
          nameKey="brand_name"
        >
          {brands.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={getRandomColor()} />
          ))}
        </Pie>
        <Tooltip />
      </PieChart>
    </>
  );
};

// Assumes that the entries are already sorted
const dataWithOtherEntry = ({ data, nameKey }) => {
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
  if (otherEntries.count < 2) {
    dataWithOther = dataWithOther.concat(otherEntries);
  } else {
    dataWithOther.push({
      [nameKey]: "Other",
      count: otherEntries.reduce((acc, { count }) => acc + count, 0),
    });
  }
  return dataWithOther;
};

const getRandomColor = () => {
  var letters = "0123456789ABCDEF";
  var color = "#";
  for (var i = 0; i < 6; i++) {
    color += letters[Math.floor(Math.random() * 16)];
  }
  return color;
};
