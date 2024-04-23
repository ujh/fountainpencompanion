import React, { useEffect, useState } from "react";
import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";

import { Spinner } from "../components/Spinner";

export const CurrentlyInked = () => {
  const [data, setData] = useState(null);
  useEffect(() => {
    fetch("/admins/graphs/currently-inked.json")
      .then((res) => res.json())
      .then((json) => setData(json));
  }, []);
  if (data) {
    const options = {
      chart: { type: "spline" },
      legend: { enabled: false },
      series: [{ data, name: "Currently Inked" }],
      title: { text: "Currently inked per day" },
      xAxis: {
        type: "datetime"
      },
      yAxis: { title: { text: "" } }
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
