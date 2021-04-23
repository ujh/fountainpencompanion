import React from "react";
import { useContext } from "react";
import { Pie, PieChart, Tooltip, Cell } from "recharts";
import { Widget, WidgetDataContext, WidgetWidthContext } from "./widgets";
import { generateColors, dataWithOtherEntry } from "./charting";

export const PensGroupedByBrandWidget = () => (
  <Widget
    header={<a href="/collected_inks">Pens</a>}
    path="/dashboard/widgets/pens_grouped_by_brand.json"
  >
    <PensGroupedByBrandWidgetContent />
  </Widget>
);

const PensGroupedByBrandWidgetContent = () => {
  const { data } = useContext(WidgetDataContext);
  const width = useContext(WidgetWidthContext);
  const brands = data.attributes.brands;
  const chartData = dataWithOtherEntry({ data: brands, nameKey: "brand_name" });
  const colors = generateColors(chartData.length);
  return (
    <>
      <p>Your inks grouped by brand</p>
      <PieChart width={width} height={width}>
        <Pie data={chartData} dataKey="count" nameKey="brand_name">
          {brands.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={colors[index]} />
          ))}
        </Pie>
        <Tooltip />
      </PieChart>
    </>
  );
};
