import { useCallback, useEffect, useMemo, useState } from "react";

const readParam = (name) => new URLSearchParams(window.location.search).get(name);

const writeParam = (name, value) => {
  const url = new URL(window.location.href);
  if (value) {
    url.searchParams.set(name, value);
  } else {
    url.searchParams.delete(name);
  }
  if (url.href === window.location.href) return;

  try {
    window.history.replaceState(window.history.state, "", url);
  } catch (e) {
    if (!(e instanceof DOMException && e.name === "SecurityError")) throw e;
  }
};

/**
 * @param {string} value
 * @param {string[]} validIds
 * @returns {{ id: string; desc: boolean }[]}
 */
export const parseSorting = (value, validIds) => {
  if (!value) return [];

  const sorting = [];
  value.split(",").forEach((part) => {
    const desc = part.startsWith("-");
    const id = desc ? part.slice(1) : part;
    if (validIds.includes(id) && !sorting.some((s) => s.id === id)) {
      sorting.push({ id, desc });
    }
  });
  return sorting;
};

/**
 * @param {{ id: string; desc: boolean }[]} sorting
 * @returns {string}
 */
export const serializeSorting = (sorting) =>
  sorting.map(({ id, desc }) => (desc ? `-${id}` : id)).join(",");

export const columnIds = (columns) =>
  columns
    .map(
      (c) =>
        c.id ??
        c.accessorKey?.replaceAll(".", "_") ??
        (typeof c.header === "string" ? c.header : null)
    )
    .filter(Boolean);

/**
 * @param {string} name
 * @returns {[string, (value: string | undefined) => void]}
 */
export const useSearchParamState = (name) => {
  const [value, setValue] = useState(() => readParam(name) || "");

  useEffect(() => {
    writeParam(name, value);
  }, [name, value]);

  const onChange = useCallback((nextValue) => setValue(nextValue || ""), []);

  return [value, onChange];
};

/**
 * @param {object[]} columns TanStack column definitions
 */
export const useUrlSorting = (columns) => {
  const validIds = useMemo(() => columnIds(columns), [columns]);
  const [sorting, setSorting] = useState(() => parseSorting(readParam("sort"), validIds));

  useEffect(() => {
    writeParam("sort", serializeSorting(sorting));
  }, [sorting]);

  return [sorting, setSorting];
};
