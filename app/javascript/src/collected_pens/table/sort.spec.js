// @ts-check
import { dateSort } from "./sort";

describe("dateSort", () => {
  it("sorts dates in ascending order (oldest to newest)", () => {
    const input = [
      { original: { last_used_on: "2026-02-22" }, getValue: () => "2026-02-22" },
      { original: { last_used_on: "2026-02-14" }, getValue: () => "2026-02-14" },
      { original: { last_used_on: "2026-02-18" }, getValue: () => "2026-02-18" }
    ];

    const result = input.sort((a, b) => dateSort(a, b, "last_used_on"));

    expect(result.map((r) => r.original.last_used_on)).toEqual([
      "2026-02-14",
      "2026-02-18",
      "2026-02-22"
    ]);
  });

  it("puts null values at the end", () => {
    const input = [
      { original: { last_used_on: "2026-02-22" }, getValue: () => "2026-02-22" },
      { original: { last_used_on: null }, getValue: () => null },
      { original: { last_used_on: "2026-02-14" }, getValue: () => "2026-02-14" },
      { original: { last_used_on: undefined }, getValue: () => undefined }
    ];

    const result = input.sort((a, b) => dateSort(a, b, "last_used_on"));
    const dates = result.map((r) => r.original.last_used_on);

    // Null/undefined values should be at the end
    expect(dates[0]).toBe("2026-02-14");
    expect(dates[1]).toBe("2026-02-22");
    expect(dates[2]).toBeNull();
    expect(dates[3]).toBeUndefined();
  });

  it("works with v7-style rows that have values", () => {
    const input = [
      { values: { last_used_on: "2026-02-22" } },
      { values: { last_used_on: "2026-02-14" } },
      { values: { last_used_on: null } }
    ];

    const result = input.sort((a, b) => dateSort(a, b, "last_used_on"));
    expect(result.map((r) => r.values.last_used_on)).toEqual(["2026-02-14", "2026-02-22", null]);
  });
});
