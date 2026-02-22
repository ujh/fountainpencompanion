// @ts-check
import { booleanSort, colorSort, dateSort } from "./sort";

describe("colorSort", () => {
  it("sorts the given color column in ascending hexadecimal value order", () => {
    const input = [
      { original: { color: "#fff" }, getValue: () => "#fff" },
      { original: { color: "#000" }, getValue: () => "#000" },
      { original: { color: "#ccc" }, getValue: () => "#ccc" }
    ];

    const expected = [
      { original: { color: "#000" }, getValue: () => "#000" },
      { original: { color: "#ccc" }, getValue: () => "#ccc" },
      { original: { color: "#fff" }, getValue: () => "#fff" }
    ];

    const result = input.sort((a, b) => colorSort(a, b, "color"));

    expect(result.map((r) => r.original.color)).toStrictEqual(
      expected.map((e) => e.original.color)
    );
  });

  it("works with v7-style rows that have values", () => {
    const input = [
      { values: { color: "#fff" } },
      { values: { color: "#000" } },
      { values: { color: "#ccc" } }
    ];

    const result = input.sort((a, b) => colorSort(a, b, "color"));
    expect(result.map((r) => r.values.color)).toEqual(["#000", "#ccc", "#fff"]);
  });

  it("handles null color values", () => {
    const input = [
      { original: { color: "#fff" }, getValue: () => "#fff" },
      { original: { color: null }, getValue: () => null },
      { original: { color: "#000" }, getValue: () => "#000" }
    ];

    const result = input.sort((a, b) => colorSort(a, b, "color"));
    const colors = result.map((r) => r.original.color);
    // Null values should appear at the end
    expect(colors[colors.length - 1]).toBe(null);
  });
});

describe("booleanSort", () => {
  it("sorts the given bool column in order of false to true", () => {
    const input = [
      { original: { swabbed: true }, getValue: () => true },
      { original: { swabbed: false }, getValue: () => false },
      { original: { swabbed: true }, getValue: () => true },
      { original: { swabbed: true }, getValue: () => true }
    ];

    const expected = [
      { original: { swabbed: false }, getValue: () => false },
      { original: { swabbed: true }, getValue: () => true },
      { original: { swabbed: true }, getValue: () => true },
      { original: { swabbed: true }, getValue: () => true }
    ];

    const result = input.sort((a, b) => booleanSort(a, b, "swabbed"));

    expect(result.map((r) => r.original.swabbed)).toStrictEqual(
      expected.map((e) => e.original.swabbed)
    );
  });

  it("works with v7-style rows that have values", () => {
    const input = [
      { values: { swabbed: true } },
      { values: { swabbed: false } },
      { values: { swabbed: true } },
      { values: { swabbed: true } }
    ];

    const result = input.sort((a, b) => booleanSort(a, b, "swabbed"));
    expect(result.map((r) => r.values.swabbed)).toEqual([false, true, true, true]);
  });

  it("handles null boolean values", () => {
    const input = [
      { original: { used: true }, getValue: () => true },
      { original: { used: null }, getValue: () => null },
      { original: { used: false }, getValue: () => false }
    ];

    const result = input.sort((a, b) => booleanSort(a, b, "used"));
    const values = result.map((r) => r.original.used);
    // Verify sorting occurred - false and true should be before null
    expect(values[0]).toBe(false);
  });
});

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
