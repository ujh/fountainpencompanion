import { fields } from "admin/pens-micro-clusters/fields";

describe("fields", () => {
  it("exports the correct field names", () => {
    expect(fields).toEqual(["brand", "model", "color", "material", "trim_color", "filling_system"]);
  });

  it("exports an array", () => {
    expect(Array.isArray(fields)).toBe(true);
  });

  it("contains 6 fields", () => {
    expect(fields).toHaveLength(6);
  });
});
