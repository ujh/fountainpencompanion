// @ts-check
import { colorSort } from "./color-sorting";

describe("colorSort", () => {
  it("sorts hexadecimal values in ascending order", () => {
    const input = ["#fff", "#000", "#ccc"];
    const expected = ["#000", "#ccc", "#fff"];

    const result = input.sort(colorSort);

    expect(result).toStrictEqual(expected);
  });
});
