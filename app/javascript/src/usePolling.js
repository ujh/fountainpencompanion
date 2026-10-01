import { useEffect, useRef } from "react";

/**
 * Calls `callback` right away and then every `interval` milliseconds, but only
 * while the page is visible. When a hidden page becomes visible again the
 * callback runs immediately, so the data is fresh without polling in the
 * background (e.g. an admin dashboard left open in a tab overnight).
 *
 * @param {() => void} callback
 * @param {number} interval
 */
export const usePolling = (callback, interval) => {
  const savedCallback = useRef(callback);

  useEffect(() => {
    savedCallback.current = callback;
  });

  useEffect(() => {
    const run = () => {
      if (!document.hidden) savedCallback.current();
    };
    run();
    const intervalId = setInterval(run, interval);
    document.addEventListener("visibilitychange", run);
    return () => {
      clearInterval(intervalId);
      document.removeEventListener("visibilitychange", run);
    };
  }, [interval]);
};
