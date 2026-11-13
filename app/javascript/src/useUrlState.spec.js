import { act, renderHook } from "@testing-library/react";
import {
  columnIds,
  parseSorting,
  serializeSorting,
  useSearchParamState,
  useUrlSorting
} from "./useUrlState";

const setUrl = (url) => window.history.replaceState(null, "", url);
const currentParams = () => new URLSearchParams(window.location.search);

describe("parseSorting", () => {
  const validIds = ["brand_name", "usage", "collected_ink_color"];

  it("returns no sorting for an empty value", () => {
    expect(parseSorting(null, validIds)).toEqual([]);
    expect(parseSorting("", validIds)).toEqual([]);
  });

  it("parses ascending and descending columns in order", () => {
    expect(parseSorting("brand_name,-usage", validIds)).toEqual([
      { id: "brand_name", desc: false },
      { id: "usage", desc: true }
    ]);
  });

  it("drops unknown columns", () => {
    expect(parseSorting("nope,-usage,-", validIds)).toEqual([{ id: "usage", desc: true }]);
  });

  it("keeps only the first occurrence of a column", () => {
    expect(parseSorting("usage,-usage", validIds)).toEqual([{ id: "usage", desc: false }]);
  });
});

describe("serializeSorting", () => {
  it("joins columns, prefixing descending ones with a dash", () => {
    expect(
      serializeSorting([
        { id: "brand_name", desc: false },
        { id: "usage", desc: true }
      ])
    ).toEqual("brand_name,-usage");
  });

  it("returns an empty string for no sorting", () => {
    expect(serializeSorting([])).toEqual("");
  });
});

describe("columnIds", () => {
  it("derives ids the way TanStack Table does", () => {
    expect(
      columnIds([
        { id: "explicit", accessorKey: "ignored" },
        { accessorKey: "brand_name" },
        { accessorKey: "collected_ink.color" },
        { header: "Actions" },
        { cell: () => null }
      ])
    ).toEqual(["explicit", "brand_name", "collected_ink_color", "Actions"]);
  });
});

describe("useSearchParamState", () => {
  it("starts with the value from the URL", () => {
    setUrl("/collected_inks?q=sailor");
    const { result } = renderHook(() => useSearchParamState("q"));
    expect(result.current[0]).toEqual("sailor");
  });

  it("starts empty without a value in the URL", () => {
    const { result } = renderHook(() => useSearchParamState("q"));
    expect(result.current[0]).toEqual("");
  });

  it("writes changes to the URL and keeps other parameters", () => {
    setUrl("/collected_inks?search%5Barchive%5D=true#top");
    const { result } = renderHook(() => useSearchParamState("q"));

    act(() => result.current[1]("blue ink"));

    expect(result.current[0]).toEqual("blue ink");
    expect(window.location.pathname).toEqual("/collected_inks");
    expect(window.location.hash).toEqual("#top");
    expect(currentParams().get("q")).toEqual("blue ink");
    expect(currentParams().get("search[archive]")).toEqual("true");
  });

  it("removes the parameter when the value is cleared", () => {
    setUrl("/collected_inks?q=sailor");
    const { result } = renderHook(() => useSearchParamState("q"));

    act(() => result.current[1](undefined));

    expect(result.current[0]).toEqual("");
    expect(currentParams().has("q")).toBe(false);
  });

  it("replaces the history entry instead of adding one", () => {
    const { result } = renderHook(() => useSearchParamState("q"));
    const length = window.history.length;

    act(() => result.current[1]("a"));
    act(() => result.current[1]("ab"));

    expect(window.history.length).toEqual(length);
  });

  it("keeps working when the browser throttles URL updates", () => {
    const { result } = renderHook(() => useSearchParamState("q"));
    const replaceState = vi.spyOn(window.history, "replaceState").mockImplementation(() => {
      throw new DOMException("Too many calls", "SecurityError");
    });

    try {
      act(() => result.current[1]("sailor"));
      expect(result.current[0]).toEqual("sailor");
    } finally {
      replaceState.mockRestore();
    }
  });

  it("does not swallow other errors from updating the URL", () => {
    const { result } = renderHook(() => useSearchParamState("q"));
    const replaceState = vi.spyOn(window.history, "replaceState").mockImplementation(() => {
      throw new TypeError("boom");
    });

    try {
      expect(() => act(() => result.current[1]("sailor"))).toThrow("boom");
    } finally {
      replaceState.mockRestore();
    }
  });
});

describe("useUrlSorting", () => {
  const columns = [{ accessorKey: "brand_name" }, { accessorKey: "usage" }];

  it("starts with the valid sorting from the URL", () => {
    setUrl("/?sort=-usage,bogus");
    const { result } = renderHook(() => useUrlSorting(columns));
    expect(result.current[0]).toEqual([{ id: "usage", desc: true }]);
  });

  it("drops invalid columns from the URL", () => {
    setUrl("/?sort=-usage,bogus");
    renderHook(() => useUrlSorting(columns));
    expect(currentParams().get("sort")).toEqual("-usage");
  });

  it("writes value and updater changes to the URL", () => {
    const { result } = renderHook(() => useUrlSorting(columns));

    act(() => result.current[1]([{ id: "brand_name", desc: false }]));
    expect(currentParams().get("sort")).toEqual("brand_name");

    act(() => result.current[1]((prev) => [...prev, { id: "usage", desc: true }]));
    expect(currentParams().get("sort")).toEqual("brand_name,-usage");

    act(() => result.current[1]([]));
    expect(currentParams().has("sort")).toBe(false);
  });
});
