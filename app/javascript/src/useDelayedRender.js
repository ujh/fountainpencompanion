import { useEffect, useState } from "react";

/**
 * Helper hook to delay rendering of a component, for instance to avoid
 * flickering when loading data.
 *
 * @param {number} delayMilliseconds
 * @returns true if delayMilliseconds has passed
 */
export function useDelayedRender(delayMilliseconds = 0) {
  const [renderComponent, setRenderComponent] = useState(delayMilliseconds === 0 ? true : false);

  useEffect(() => {
    if (delayMilliseconds === 0) {
      return;
    }

    const timeout = setTimeout(() => setRenderComponent(true), delayMilliseconds);
    return () => clearTimeout(timeout);
  }, [delayMilliseconds, setRenderComponent]);

  return renderComponent;
}
