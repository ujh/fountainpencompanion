import { computeAverageColor } from "edit-colors/color-utils";

describe("computeAverageColor", () => {
  it("returns null for empty array", () => {
    expect(computeAverageColor([])).toBeNull();
  });

  it("returns the same color for a single color", () => {
    expect(computeAverageColor(["#ff0000"])).toBe("#ff0000");
  });

  it("computes quadratic mean of multiple colors", () => {
    // red and blue: RMS of (255,0) = 180, RMS of (0,0) = 0, RMS of (0,255) = 180
    const result = computeAverageColor(["#ff0000", "#0000ff"]);
    expect(result).toBe("#b400b4");
  });

  it("handles black and white", () => {
    const result = computeAverageColor(["#000000", "#ffffff"]);
    // RMS of (0,255) for each channel = 180
    expect(result).toBe("#b4b4b4");
  });

  it("handles colors with uppercase hex", () => {
    expect(computeAverageColor(["#FF0000"])).toBe("#ff0000");
  });
});
