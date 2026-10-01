import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";
import { useState } from "react";
import { getRequest } from "../../fetch";
import { usePolling } from "../../usePolling";
import { Spinner } from "../components/Spinner";

export const BotSignUps = () => {
  const [data, setData] = useState(null);
  usePolling(() => {
    navigator.locks.request("admin-dashboard", async () =>
      getRequest("/admins/graphs/bot-signups.json")
        .then((res) => res.json())
        .then((json) => setData(json))
    );
  }, 1000 * 30);
  if (data) {
    const options = {
      chart: { type: "spline" },
      legend: { enabled: true },
      series: data,
      title: { text: "Bot signups per day" },
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
