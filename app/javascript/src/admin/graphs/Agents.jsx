import React, { useEffect, useState } from "react";
import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";

import { Spinner } from "../components/Spinner";
import { getRequest } from "../../fetch";

export const Agents = () => {
  const [data, setData] = useState(null);
  useEffect(() => {
    navigator.locks.request("admin-dashboard", async () =>
      getRequest("/admins/graphs/agents.json")
        .then((res) => res.json())
        .then((json) => setData(json))
    );
  }, []);
  if (data) {
    const options = {
      chart: { type: "spline" },
      legend: { enabled: true },
      series: data,
      title: { text: "Agent executions per day" },
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
