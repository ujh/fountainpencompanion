import { useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { ErrorBoundary } from "../ErrorBoundary";
import { getRequest } from "../fetch";
import { usePolling } from "../usePolling";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".stats");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(
      <ErrorBoundary>
        <Stat id={el.dataset.id} arg={el.dataset.arg} />
      </ErrorBoundary>
    );
  });
});

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll(".conditional-stats");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(
      <ErrorBoundary>
        <ConditionalStat
          id={el.dataset.id}
          arg={el.dataset.arg}
          href={el.dataset.href}
          template={el.dataset.template}
        />
      </ErrorBoundary>
    );
  });
});

const useAdminStat = (id, arg) => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  // All stats share one lock, so a reload can wait in the queue for a while. Skip
  // polls while one is pending so reloads don't stack up (e.g. after tab focus).
  const pending = useRef(false);
  usePolling(() => {
    if (pending.current) return;
    pending.current = true;
    navigator.locks.request("admin-dashboard-stats", async () => {
      setLoading(true);
      try {
        let url = `/admins/stats/${id}`;
        if (arg) url += `?arg=${arg}`;
        const response = await getRequest(url);
        const json = await response.json();
        setData(json);
      } finally {
        pending.current = false;
        setLoading(false);
      }
    });
  }, 1000 * 30);
  return { data, loading };
};

const LoadingIndicator = () => (
  <>
    <i className="fa fa-spin fa-refresh" />
    &nbsp;
  </>
);

export const Stat = ({ id, arg }) => {
  const { data, loading } = useAdminStat(id, arg);
  return (
    <>
      {data !== null && <>{data} </>}
      {loading && <LoadingIndicator />}
    </>
  );
};

export const ConditionalStat = ({ id, arg, href, template }) => {
  const { data, loading } = useAdminStat(id, arg);
  if (!data && !loading) return null;

  return (
    <>
      &nbsp;
      {data && (
        <b>
          ( <a href={href}>{template.replace("%count%", data)}</a> )
        </b>
      )}
      {data && loading && <>&nbsp;</>}
      {loading && <LoadingIndicator />}
    </>
  );
};
