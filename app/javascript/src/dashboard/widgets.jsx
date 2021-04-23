import React, { useEffect, useState } from "react";
import { getRequest } from "../fetch";

export const WidgetDataContext = React.createContext();

export const Widget = ({ header, children, path }) => {
  const [data, setData] = useState(null);
  useEffect(() => {
    async function fetchData() {
      const response = await getRequest(path);
      const data = await response.json();
      setData(data);
    }
    fetchData();
  }, []);
  let content = <Loader />;
  if (data) {
    content = (
      <WidgetDataContext.Provider value={data}>
        {children}
      </WidgetDataContext.Provider>
    );
  }
  return (
    <div className="col-sm-12 col-md-6">
      <div className="widget">
        <h4>{header}</h4>
        <div>{content}</div>
      </div>
    </div>
  );
};

const Loader = () => (
  <div className="loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);
