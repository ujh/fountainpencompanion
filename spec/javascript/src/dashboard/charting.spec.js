import { dataWithOtherEntry } from "dashboard/charting";

describe("dataWithOtherEntry", () => {
  it("combines the last 10% to an entry", () => {
    const data = [
      { count: 10, name: "a" },
      { count: 10, name: "b" },
      { count: 1, name: "c" },
      { count: 1, name: "d" },
    ];
    const result = dataWithOtherEntry({ data, nameKey: "name" });
    expect(result).toStrictEqual([
      { count: 10, name: "a" },
      { count: 10, name: "b" },
      { count: 2, name: "Other" },
    ]);
  });

  it("does not combine if only one entry too small", () => {
    const data = [
      { count: 10, name: "a" },
      { count: 10, name: "b" },
      { count: 1, name: "c" },
    ];
    const result = dataWithOtherEntry({ data, nameKey: "name" });
    expect(result).toStrictEqual([
      { count: 10, name: "a" },
      { count: 10, name: "b" },
      { count: 1, name: "c" },
    ]);
  });
});
