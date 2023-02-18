// @ts-check
import { booleanSort, colorSort } from "./sort";

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

describe("booleanSort", () => {
  it("sorts the given bool column in order of false to true", () => {
    const input = [
      { values: { swabbed: true } },
      { values: { swabbed: false } },
      { values: { swabbed: true } },
      { values: { swabbed: true } }
    ];

    const expected = [
      { values: { swabbed: false } },
      { values: { swabbed: true } },
      { values: { swabbed: true } },
      { values: { swabbed: true } }
    ];

    const result = input.sort((a, b) => booleanSort(a, b, "swabbed"));

    expect(result).toStrictEqual(expected);
  });
});
