import React, { useEffect, useState } from "react";
import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";

import { Spinner } from "../components/Spinner";
import { getRequest } from "../../fetch";

export const CurrentlyInked = () => {
  const [data, setData] = useState(null);
  useEffect(() => {
    const fetchData = () => {
      navigator.locks.request("admin-dashboard", async () =>
        getRequest("/admins/graphs/currently-inked.json")
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
