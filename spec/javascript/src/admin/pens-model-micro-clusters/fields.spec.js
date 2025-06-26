import { fields } from "admin/pens-model-micro-clusters/fields";

describe("fields", () => {
  it("exports the correct field names", () => {
    expect(fields).toEqual(["brand", "model"]);
  });

  it("exports an array", () => {
    expect(Array.isArray(fields)).toBe(true);
  });

  it("contains 2 fields", () => {
    expect(fields).toHaveLength(2);
  });
});
