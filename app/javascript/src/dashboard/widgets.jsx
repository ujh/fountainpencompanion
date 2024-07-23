import React, { useEffect, useState } from "react";
import ResizeObserver from "rc-resize-observer";
import TrackVisibility from "react-on-screen";
import Jsona from "jsona";

import { getRequest } from "../fetch";

const formatter = new Jsona();

export const WidgetDataContext = React.createContext();
export const WidgetWidthContext = React.createContext();

const Loader = ({ withLinks }) => (
  <div className=" placeholder-glow">
    <p className="card-text">
      <span className="placeholder col-12" />
      <span className="placeholder col-12" />
      <span className="placeholder col-12" />
    </p>
    {withLinks && (
      <span
        className="placeholder col-4 bg-primary"
        style={{ marginBottom: "-58px" }}
      />
    )}
  </div>
);

export const Widget = ({ renderWhenInvisible, ...rest }) => {
  if (renderWhenInvisible) {
    return <WidgetCard {...rest} isVisible={true} />;
  }

  return (
    <TrackVisibility once partialVisibility>
      {({ isVisible }) => <WidgetCard {...rest} isVisible={isVisible} />}
    </TrackVisibility>
  );
};

const WidgetCard = ({ withLinks, header, subtitle, isVisible, ...rest }) => {
  return (
    <div
      className={`card fpc-dashboard-widget ${
        withLinks ? "fpc-dashboard-widget--with-links" : ""
      }`}
    >
      <div className="card-body">
        <h2 className="h4 card-title">{header}</h2>
        {subtitle && <p className="card-subtitle text-muted">{subtitle}</p>}
        {isVisible ? (
          <WidgetContent withLinks={withLinks} {...rest} />
        ) : (
          <Loader withLinks={withLinks} />
        )}
      </div>
    </div>
  );
};

const WidgetContent = ({ children, path, withLinks, paginated }) => {
  const [data, setData] = useState(null);
  useEffect(() => {
    if (!path) return;

    async function fetchData() {
      if (paginated) {
        setData(await getPaginatedData(path));
      } else {
        setData(await getData(path));
      }
    }
    fetchData();
  }, [path, paginated]);
  const [elementWidth, setElementWidth] = useState(0);
  let content = <Loader withLinks={withLinks} />;

  if (data || !path) {
    content = (
      <WidgetDataContext.Provider value={data}>
        <WidgetWidthContext.Provider value={elementWidth}>
          {children}
        </WidgetWidthContext.Provider>
      </WidgetDataContext.Provider>
    );
  }
  return (
    <ResizeObserver onResize={({ width }) => setElementWidth(width)}>
      <div className="mt-2">{content}</div>
    </ResizeObserver>
  );
};

const getData = async (path) => {
  const response = await getRequest(path);
  return response.json();
};

const getPaginatedData = async (path) => {
  let receivedData = [];
  let page = 1;
  do {
    const json = await getPage(path, page);
    page = json.meta.pagination.next_page;
    receivedData.push(...formatter.deserialize(json));
  } while (page);
  return receivedData;
};

const getPage = async (path, page) => {
  const response = await getRequest(`${path}?page[number]=${page}`);
  const json = await response.json();
  return json;
};
