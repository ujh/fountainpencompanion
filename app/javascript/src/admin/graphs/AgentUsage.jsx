import React, { useEffect, useState } from "react";
import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";

import { Spinner } from "../components/Spinner";
import { getRequest } from "../../fetch";

export const AgentUsage = () => {
  const [data, setData] = useState(null);
  useEffect(() => {
    const fetchData = () => {
      navigator.locks.request("admin-dashboard", async () =>
        getRequest("/admins/graphs/agent-usage.json")
          .then((res) => res.json())
          .then((json) => setData(json))
      );
    };
    fetchData();
    const interval = setInterval(fetchData, 1000 * 30);
    return () => clearInterval(interval);
  }, []);
  if (data) {
    const options = {
      chart: { type: "column" },
      legend: { enabled: true },
      series: data,
      title: { text: "Agent tokens per day" },
      xAxis: {
        type: "datetime"
      },
      yAxis: { title: { text: "" } },
      plotOptions: {
        column: {
          stacking: "normal"
        }
      }
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
