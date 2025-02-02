import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import { getRequest } from "../fetch";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".stats");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(<Stat id={el.dataset.id} arg={el.dataset.arg} />);
  });
});

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".conditional-stats");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(
      <ConditionalStat
        id={el.dataset.id}
        arg={el.dataset.arg}
        href={el.dataset.href}
        template={el.dataset.template}
      />
    );
  });
});

const Stat = ({ id, arg }) => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    navigator.locks.request("admin-dashboard", async () => {
      let url = `/admins/stats/${id}`;
      if (arg) url += `?arg=${arg}`;
      const response = await getRequest(url);
      const json = await response.json();
      setData(json);
      setLoading(false);
    });
  });
  if (loading) {
    return (
      <>
        <i className="fa fa-spin fa-refresh" />
        &nbsp;
      </>
    );
  } else {
    return <>{data} </>;
  }
};

const ConditionalStat = ({ id, arg, href, template }) => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    navigator.locks.request("admin-dashboard", async () => {
      let url = `/admins/stats/${id}`;
      if (arg) url += `?arg=${arg}`;
      const response = await getRequest(url);
      const json = await response.json();
      setData(json);
      setLoading(false);
    });
  });
  if (loading) {
    return (
      <>
        &nbsp;
        <i className="fa fa-spin fa-refresh" />
        &nbsp;
      </>
    );
  } else if (data) {
    return (
      <>
        &nbsp;
        <b>
          ( <a href={href}>{template.replace("%count%", data)}</a> )
        </b>
      </>
    );
  } else {
    return null;
  }
};
