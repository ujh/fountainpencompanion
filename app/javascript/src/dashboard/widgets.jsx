import React, { useEffect, useState } from "react";
import ResizeObserver from "rc-resize-observer";
import TrackVisibility from "react-on-screen";
import { getRequest } from "../fetch";

export const WidgetDataContext = React.createContext();
export const WidgetWidthContext = React.createContext();

export const Widget = (props) => {
  return (
    <div className="col-sm-12 col-md-6">
      <div className="widget">
        <WidgetContentVisibility {...props} />
      </div>
    </div>
  );
};

// Workaround as the tests as the TrackVisibility component never detects that something is visible during the tests
const WidgetContentVisibility = (props) => {
  if (props.renderWhenInvisible) {
    return <WidgetContent {...props} />;
  } else {
    return (
      <TrackVisibility once>
        {({ isVisible }) => isVisible && <WidgetContent {...props} />}
      </TrackVisibility>
    );
  }
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
  <div className="loader">
    <i className="fa fa-spin fa-refresh" />
  </div>
);
