import React, { useEffect, useState } from "react";
import ResizeObserver from "rc-resize-observer";
import TrackVisibility from "react-on-screen";
import { getRequest } from "../fetch";

export const WidgetDataContext = React.createContext();
export const WidgetWidthContext = React.createContext();

export const Widget = ({ withLinks, ...rest }) => {
  return (
    <div
      className={`card fpc-dashboard-widget ${
        withLinks ? "fpc-dashboard-widget--with-links" : ""
      }`}
    >
      <div className="card-body">
        <TrackVisibility once>
          {({ isVisible }) => isVisible && <WidgetContent {...rest} />}
        </TrackVisibility>
      </div>
    </div>
  );
};

const WidgetContent = ({ header, subtitle, children, path }) => {
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
      <h2 className="h4 card-title">{header}</h2>
      {subtitle && <p className="card-subtitle text-muted">{subtitle}</p>}
      <ResizeObserver onResize={({ width }) => setElementWidth(width)}>
        <div className="mt-2">{content}</div>
      </ResizeObserver>
    </>
  );
};

const Loader = () => (
  <div className="fpc-widget__loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);
