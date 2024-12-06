import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".stats");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(<Stat id={el.dataset.id} />);
  });
});

const Stat = ({ id }) => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    async function load() {
      const response = await fetch(`/admins/stats/${id}`);
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
