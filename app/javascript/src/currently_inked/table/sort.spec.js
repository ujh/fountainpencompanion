// @ts-check
import { colorSort } from "./sort";

describe("colorSort", () => {
  it("sorts the given color column in ascending hexadecimal value order", () => {
    const input = [
      { values: { color: "#fff" } },
      { values: { color: "#000" } },
      { values: { color: "#ccc" } }
    ];

    const expected = [
      { values: { color: "#000" } },
      { values: { color: "#ccc" } },
      { values: { color: "#fff" } }
    ];

    const result = input.sort((a, b) => colorSort(a, b, "color"));

    expect(result).toStrictEqual(expected);
  });
});
