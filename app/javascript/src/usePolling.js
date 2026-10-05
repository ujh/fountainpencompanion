import { useEffect, useRef } from "react";

/**
 * Calls `callback` right away and then every `interval` milliseconds, but only
 * while the page is visible. When a hidden page becomes visible again and the
 * last call is at least `interval` old, the callback runs immediately and the
 * interval restarts from there, so the data is fresh without polling in the
 * background (e.g. an admin dashboard left open in a tab overnight) and without
 * reloading on every quick tab switch.
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
    let lastRunAt = 0;
    let intervalId;

    const run = () => {
      if (document.hidden) return;
      lastRunAt = Date.now();
      savedCallback.current();
    };
    const startTicking = () => {
      clearInterval(intervalId);
      intervalId = setInterval(run, interval);
    };
    const onVisibilityChange = () => {
      if (document.hidden || Date.now() - lastRunAt < interval) return;
      run();
      startTicking();
    };

    run();
    startTicking();
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => {
      clearInterval(intervalId);
      document.removeEventListener("visibilitychange", onVisibilityChange);
    };
  }, [interval]);
};
