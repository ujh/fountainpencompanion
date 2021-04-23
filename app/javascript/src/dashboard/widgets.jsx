import React, { useEffect, useState } from "react";
import ResizeObserver from "rc-resize-observer";
import { getRequest } from "../fetch";

export const WidgetDataContext = React.createContext();
export const WidgetWidthContext = React.createContext();

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
  const [elementWidth, setElementWidth] = useState(0);
  let content = <Loader />;
  if (data) {
    content = (
      <WidgetDataContext.Provider value={data}>
        <WidgetWidthContext.Provider value={elementWidth}>
          {children}
        </WidgetWidthContext.Provider>
      </WidgetDataContext.Provider>
    );
  }
  return (
    <div className="col-sm-12 col-md-6">
      <div className="widget">
        <h4>{header}</h4>
        <ResizeObserver onResize={({ width }) => setElementWidth(width)}>
          <div>{content}</div>
        </ResizeObserver>
      </div>
    </div>
  );
};

const Loader = () => (
  <div className="loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);
