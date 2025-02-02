import React, { useEffect, useState } from "react";
import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";

import { Spinner } from "../components/Spinner";
import { getRequest } from "../../fetch";

export const Spam = () => {
  const [data, setData] = useState(null);
  useEffect(() => {
    navigator.locks.request("admin-dashboard", async () =>
      getRequest("/admins/graphs/spam.json")
        .then((res) => res.json())
        .then((json) => setData(json))
    );
  }, []);
  if (data) {
    const options = {
      chart: { type: "spline" },
      legend: { enabled: true },
      series: data,
      title: { text: "Spam accounts" },
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
