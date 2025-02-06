// @ts-check
// Inspired by https://github.com/fremtind/jokul/blob/main/packages/react-hooks/src/useScreen/useScreen.ts
// but with a subset of breakpoints from Bootstrap 5
import { useCallback, useEffect, useReducer } from "react";

/**
 * @typedef {{ isSmall: boolean; isMedium: boolean; isLarge: boolean }} ScreenState
 * @typedef {"small" | "medium" | "large"} ScreenSize
 */
/**
 *
 * @param {ScreenState} state
 * @param {{ type: "size"; property: ScreenSize }} action
 * @returns {ScreenState}
 */
const reducer = (state, action) => {
  switch (action.type) {
    case "size": {
      return {
        ...state,
        isSmall: action.property === "small",
        isMedium: action.property === "medium",
        isLarge: action.property === "large"
      };
    }
    default: {
      return state;
    }
  }
};

// https://getbootstrap.com/docs/5.3/layout/breakpoints/
/**
 * @type {Record<ScreenSize, string>}
 */
const mediaQueries = {
  large: "(min-width: 993px)",
  medium: "(min-width: 769px) and (max-width: 992px)",
  small: "(max-width: 768px)"
};

/**
 * @returns {ScreenState}
 */
export const useScreen = () => {
  const [state, dispatch] = useReducer(reducer, {
    isSmall: false,
    isMedium: false,
    isLarge: false
  });

  useEffect(() => {
    if (!window.matchMedia) {
      return;
    }

    /**
     * @type {[ScreenSize, string][]}
     */
    // @ts-ignore
    const queries = Object.entries(mediaQueries);
    /**
     * @type {[ScreenSize, boolean][]}
     */
    const queryResults = queries.map(([size, query]) => [size, window.matchMedia(query).matches]);

    for (const [size, matches] of queryResults) {
      if (matches) {
        dispatch({ type: "size", property: size });
      }
    }
  }, []);

  const makeListener = useCallback(
    /**
     * @param {ScreenSize} size
     * @returns {(event: MediaQueryListEvent) => void}
     */
    (size) => (event) => {
      requestAnimationFrame(() => {
        if (event.matches) {
          dispatch({ type: "size", property: size });
        }
      });
    },
    []
  );

  useEffect(() => {
    if (!window.matchMedia) {
      return;
    }

    const listeners = [];

    /**
     * @type {[ScreenSize, string][]}
     */
    // @ts-ignore
    const queries = Object.entries(mediaQueries);

    for (const [size, query] of queries) {
      const queryList = window.matchMedia(query);
      const listener = makeListener(size);
      listeners.push(queryList, listener);
      queryList.addEventListener("change", listener);
    }

    return () => {
      listeners.forEach(([queryList, listener]) =>
        queryList.removeEventListener("change", listener)
      );
    };
  }, [makeListener]);

  return state;
};
