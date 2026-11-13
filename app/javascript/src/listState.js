import { createContext, useCallback, useContext } from "react";

/** @type {import('react').Context<{ q?: string; sort?: string }>} */
export const ListStateContext = createContext({});

/**
 * @param {string} href
 * @param {{ q?: string; sort?: string }} listState
 * @returns {string}
 */
export const withListState = (href, { q, sort } = {}) => {
  if (!q && !sort) return href;

  const url = new URL(href, window.location.origin);
  if (q) url.searchParams.set("q", q);
  if (sort) url.searchParams.set("sort", sort);
  return url.pathname + url.search;
};

/**
 * @returns {(href: string) => string}
 */
export const useWithListState = () => {
  const listState = useContext(ListStateContext);
  return useCallback((href) => withListState(href, listState), [listState]);
};
