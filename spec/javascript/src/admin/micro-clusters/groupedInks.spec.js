import { groupedInks } from "admin/micro-clusters/groupedInks";

describe("groupedInks", () => {
  it("returns only unique inks", () => {
    const inks = [
      { brand_name: "brand1", line_name: "line1", ink_name: "ink1" },
      { brand_name: "brand1", line_name: "line1", ink_name: "ink1" },
      { brand_name: "brand2", line_name: "line1", ink_name: "ink1" }
    ];
    expect(groupedInks(inks)).toStrictEqual([
      { brand_name: "brand1", line_name: "line1", ink_name: "ink1" },
      { brand_name: "brand2", line_name: "line1", ink_name: "ink1" }
    ]);
  });
});
