import React, { useEffect, useState } from "react";
import ResizeObserver from "rc-resize-observer";
import TrackVisibility from "react-on-screen";
import { getRequest } from "../fetch";

export const WidgetDataContext = React.createContext();
export const WidgetWidthContext = React.createContext();

export const Widget = (props) => {
  return (
    <div className="col-md-12 col-lg-6">
      <div className="fpc-dashboard-widget">
        <TrackVisibility once>
          {({ isVisible }) => isVisible && <WidgetContent {...props} />}
        </TrackVisibility>
      </div>
    </div>
  );
};

const WidgetContent = ({ header, children, path }) => {
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
    <>
      <h4>{header}</h4>
      <ResizeObserver onResize={({ width }) => setElementWidth(width)}>
        <div>{content}</div>
      </ResizeObserver>
    </>
  );
};

const Loader = () => (
  <div className="fpc-widget__loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);
