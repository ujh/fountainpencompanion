import React from "react";
import { useContext } from "react";
import { Pie, PieChart, Tooltip, Cell } from "recharts";
import { Widget, WidgetDataContext, WidgetWidthContext } from "./widgets";
import { dataWithOtherEntry, generateColors } from "./charting";

export const InksGroupedByBrandWidget = () => (
  <Widget
    header="Inks"
    subtitle="Your inks grouped by brand"
    path="/dashboard/widgets/inks_grouped_by_brand.json"
  >
    <InksGroupedByBrandWidgetContent />
  </Widget>
);

const InksGroupedByBrandWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const width = useContext(WidgetWidthContext);
  const brands = data.attributes.brands;
  const chartData = dataWithOtherEntry({ data: brands, nameKey: "brand_name" });
  const colors = generateColors(chartData.length);
  return (
    <PieChart width={width} height={width}>
      <Pie data={chartData} dataKey="count" nameKey="brand_name">
        {brands.map((entry, index) => (
          <Cell key={`cell-${index}`} fill={colors[index]} />
        ))}
      </Pie>
      <Tooltip />
    </PieChart>
  );
};
