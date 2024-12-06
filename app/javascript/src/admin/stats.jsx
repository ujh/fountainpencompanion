import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".stats");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(<Stat id={el.dataset.id} arg={el.dataset.arg} />);
  });
});

const Stat = ({ id, arg }) => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    async function load() {
      let url = `/admins/stats/${id}`;
      if (arg) url += `?arg=${arg}`;
      const response = await fetch(url);
      const json = await response.json();
      setData(json);
      setLoading(false);
    }
    load();
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
