import { renderHook } from "@testing-library/react";
import { ListStateContext, useWithListState, withListState } from "./listState";

describe("withListState", () => {
  it("returns the href unchanged without list state", () => {
    expect(withListState("/collected_inks/new", {})).toEqual("/collected_inks/new");
    expect(withListState("/collected_inks/new", { q: "", sort: "" })).toEqual(
      "/collected_inks/new"
    );
  });

  it("adds the search and the sorting", () => {
    const href = withListState("/collected_inks/1/edit", {
      q: "blue ink",
      sort: "brand_name,-usage"
    });
    const url = new URL(href, window.location.origin);

    expect(url.pathname).toEqual("/collected_inks/1/edit");
    expect(url.searchParams.get("q")).toEqual("blue ink");
    expect(url.searchParams.get("sort")).toEqual("brand_name,-usage");
  });

  it("keeps the parameters already in the href", () => {
    const href = withListState("/collected_inks/1/edit?search[archive]=true", { q: "sailor" });
    const url = new URL(href, window.location.origin);

    expect(url.searchParams.get("search[archive]")).toEqual("true");
    expect(url.searchParams.get("q")).toEqual("sailor");
    expect(url.searchParams.has("sort")).toBe(false);
  });
});

describe("useWithListState", () => {
  it("leaves hrefs unchanged outside of a list", () => {
    const { result } = renderHook(() => useWithListState());
    expect(result.current("/collected_pens/new")).toEqual("/collected_pens/new");
  });

  it("adds the list state of the surrounding list", () => {
    const wrapper = ({ children }) => (
      <ListStateContext value={{ q: "pilot", sort: "-usage" }}>{children}</ListStateContext>
    );
    const { result } = renderHook(() => useWithListState(), { wrapper });

    expect(result.current("/collected_pens/new")).toEqual(
      "/collected_pens/new?q=pilot&sort=-usage"
    );
  });
});
