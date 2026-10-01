import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";
import { useState } from "react";
import { getRequest } from "../../fetch";
import { usePolling } from "../../usePolling";
import { Spinner } from "../components/Spinner";

export const UsageRecords = () => {
  const [data, setData] = useState(null);
  usePolling(() => {
    navigator.locks.request("admin-dashboard", async () =>
      getRequest("/admins/graphs/usage-records.json")
        .then((res) => res.json())
        .then((json) => setData(json))
    );
  }, 1000 * 30);
  if (data) {
    const options = {
      chart: { type: "spline" },
      legend: { enabled: false },
      series: [{ data, name: "Usage Records" }],
      title: { text: "Usage records per day" },
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
