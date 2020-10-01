import React, { useEffect, useState } from "react";
import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";

import { Spinner } from "../micro-clusters/Spinner";

export const CollectedPens = () => {
  const [data, setData] = useState(null);
  useEffect(() => {
    fetch("/admins/graphs/collected-pens.json")
      .then((res) => res.json())
      .then((json) => setData(json));
  }, []);
  if (data) {
    const options = {
      chart: { type: "spline" },
      legend: { enabled: false },
      series: [{ data, name: "Collected Pens" }],
      title: { text: "Collected pens per day" },
      xAxis: {
        type: "datetime",
      },
      yAxis: { title: { text: "" } },
    };
    return (
      <div>
        <HighchartsReact highcharts={Highcharts} options={options} />
      </div>
    );
  } else {
    return (
      <div>
        <Spinner />
      </div>
    );
  }
};
