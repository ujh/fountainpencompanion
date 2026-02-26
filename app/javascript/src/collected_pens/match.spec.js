// @ts-check
import { fuzzyMatch } from "./match";

describe("fuzzyMatch", () => {
  const input = [
    {
      brand: "Pilot",
      model: "Custom 823",
      nib: "M",
      color: "Amber",
      comment: "",
      usage: 1,
      daily_usage: 0
    },
    {
      brand: "Platinum",
      model: "#3776 Century",
      nib: "F",
      color: "Black Diamond",
      comment: "",
      usage: 1,
      daily_usage: 1
    },
    {
      brand: "Sailor",
      model: "Pro Gear",
      nib: "M",
      color: "Black",
      comment: "",
      usage: 1,
      daily_usage: 1
    },
    {
      brand: "Sailor",
      model: "Profit Casual",
      nib: "Zoom",
      color: "Red",
      comment: "",
      usage: 1,
      daily_usage: 0
    }
  ];

  it("matches and sorts by relevance", () => {
    expect(fuzzyMatch(input, "sail")).toStrictEqual([
      {
        brand: "Sailor",
        model: "Pro Gear",
        nib: "M",
        color: "Black",
        comment: "",
        usage: 1,
        daily_usage: 1
      },
      {
        brand: "Sailor",
        model: "Profit Casual",
        nib: "Zoom",
        color: "Red",
        comment: "",
        usage: 1,
        daily_usage: 0
      }
    ]);

    expect(fuzzyMatch(input, "amber")).toStrictEqual([
      {
        brand: "Pilot",
        model: "Custom 823",
        nib: "M",
        color: "Amber",
        comment: "",
        usage: 1,
        daily_usage: 0
      }
    ]);

    expect(fuzzyMatch(input, "3776")).toStrictEqual([
      {
        brand: "Platinum",
        model: "#3776 Century",
        nib: "F",
        color: "Black Diamond",
        comment: "",
        usage: 1,
        daily_usage: 1
      }
    ]);
  });

  it("handles an undefined filterValue", () => {
    expect(fuzzyMatch(input, undefined).length).toEqual(input.length);
  });

  describe("with hidden fields", () => {
    it("does not match on hidden fields", () => {
      // "Amber" is a color value - should not match when color is hidden
      expect(fuzzyMatch(input, "amber", ["color"])).toStrictEqual([]);

      // Brand should still be searchable when color is hidden
      expect(fuzzyMatch(input, "sail", ["color"])).toStrictEqual([
        {
          brand: "Sailor",
          model: "Pro Gear",
          nib: "M",
          color: "Black",
          comment: "",
          usage: 1,
          daily_usage: 1
        },
        {
          brand: "Sailor",
          model: "Profit Casual",
          nib: "Zoom",
          color: "Red",
          comment: "",
          usage: 1,
          daily_usage: 0
        }
      ]);
    });

    it("does not match on hidden brand field", () => {
      // "Sailor" is a brand - should not match when brand is hidden
      expect(fuzzyMatch(input, "sailor", ["brand"])).toStrictEqual([]);

      // Model should still be searchable
      expect(fuzzyMatch(input, "3776", ["brand"])).toStrictEqual([
        {
          brand: "Platinum",
          model: "#3776 Century",
          nib: "F",
          color: "Black Diamond",
          comment: "",
          usage: 1,
          daily_usage: 1
        }
      ]);
    });

    it("does not match on multiple hidden fields", () => {
      // Brand and color are hidden, nib "Zoom" should still match
      expect(fuzzyMatch(input, "zoom", ["brand", "color"])).toStrictEqual([
        {
          brand: "Sailor",
          model: "Profit Casual",
          nib: "Zoom",
          color: "Red",
          comment: "",
          usage: 1,
          daily_usage: 0
        }
      ]);

      // Nib is also hidden - "Zoom" should no longer match
      expect(fuzzyMatch(input, "zoom", ["brand", "color", "nib"])).toStrictEqual([]);
    });

    it("handles an undefined filterValue with hidden fields", () => {
      expect(fuzzyMatch(input, undefined, ["brand", "color"]).length).toEqual(input.length);
    });
  });
});
