// @ts-check
import { fuzzyMatch } from "./match";

describe("fuzzyMatch", () => {
  const input = [
    {
      original: {
        brand: "Pilot",
        model: "Custom 823",
        nib: "M",
        color: "Amber",
        comment: "",
        usage: 1,
        daily_usage: 0
      }
    },
    {
      original: {
        brand: "Platinum",
        model: "#3776 Century",
        nib: "F",
        color: "Black Diamond",
        comment: "",
        usage: 1,
        daily_usage: 1
      }
    },
    {
      original: {
        brand: "Sailor",
        model: "Pro Gear",
        nib: "M",
        color: "Black",
        comment: "",
        usage: 1,
        daily_usage: 1
      }
    },
    {
      original: {
        brand: "Sailor",
        model: "Profit Casual",
        nib: "Zoom",
        color: "Red",
        comment: "",
        usage: 1,
        daily_usage: 0
      }
    }
  ];

  describe("with no hidden fields", () => {
    it("matches and sorts by relevance", () => {
      const mockAddMeta = jest.fn();

      // Test that Sailor rows match "sail" filter
      expect(fuzzyMatch(input[0], null, { filterValue: "sail" }, mockAddMeta)).toBe(false);
      expect(fuzzyMatch(input[1], null, { filterValue: "sail" }, mockAddMeta)).toBe(false);
      expect(fuzzyMatch(input[2], null, { filterValue: "sail" }, mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[3], null, { filterValue: "sail" }, mockAddMeta)).toBe(true);

      // Test that only Pilot row matches "amber" filter
      expect(fuzzyMatch(input[0], null, { filterValue: "amber" }, mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[1], null, { filterValue: "amber" }, mockAddMeta)).toBe(false);
      expect(fuzzyMatch(input[2], null, { filterValue: "amber" }, mockAddMeta)).toBe(false);
      expect(fuzzyMatch(input[3], null, { filterValue: "amber" }, mockAddMeta)).toBe(false);

      // Test that only Platinum row matches "3776" filter
      expect(fuzzyMatch(input[0], null, { filterValue: "3776" }, mockAddMeta)).toBe(false);
      expect(fuzzyMatch(input[1], null, { filterValue: "3776" }, mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[2], null, { filterValue: "3776" }, mockAddMeta)).toBe(false);
      expect(fuzzyMatch(input[3], null, { filterValue: "3776" }, mockAddMeta)).toBe(false);

      // Test that fuzzy matching works
      expect(fuzzyMatch(input[0], null, { filterValue: "spg" }, mockAddMeta)).toBe(false);
      expect(fuzzyMatch(input[1], null, { filterValue: "spg" }, mockAddMeta)).toBe(false);
      expect(fuzzyMatch(input[2], null, { filterValue: "spg" }, mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[3], null, { filterValue: "spg" }, mockAddMeta)).toBe(false);
    });

    it("returns true when filterValue is empty", () => {
      const mockAddMeta = jest.fn();

      expect(fuzzyMatch(input[0], null, { filterValue: "" }, mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[0], null, {}, mockAddMeta)).toBe(true);
    });
  });

  describe("with hidden fields", () => {
    it("does not match on hidden fields", () => {
      const mockAddMeta = jest.fn();

      // "Amber" is a color value - should not match when color is hidden
      expect(
        fuzzyMatch(input[0], null, { filterValue: "amber", hiddenFields: ["color"] }, mockAddMeta)
      ).toBe(false);

      // "Black Diamond" is a color value - should not match when color is hidden
      expect(
        fuzzyMatch(input[1], null, { filterValue: "diamond", hiddenFields: ["color"] }, mockAddMeta)
      ).toBe(false);

      // Brand should still be searchable
      expect(
        fuzzyMatch(input[0], null, { filterValue: "pilot", hiddenFields: ["color"] }, mockAddMeta)
      ).toBe(true);
      expect(
        fuzzyMatch(input[2], null, { filterValue: "sail", hiddenFields: ["color"] }, mockAddMeta)
      ).toBe(true);
    });

    it("does not match on hidden brand field", () => {
      const mockAddMeta = jest.fn();

      // "Sailor" is a brand - should not match when brand is hidden
      expect(
        fuzzyMatch(input[2], null, { filterValue: "sailor", hiddenFields: ["brand"] }, mockAddMeta)
      ).toBe(false);
      expect(
        fuzzyMatch(input[3], null, { filterValue: "sailor", hiddenFields: ["brand"] }, mockAddMeta)
      ).toBe(false);

      // Model should still be searchable
      expect(
        fuzzyMatch(
          input[2],
          null,
          { filterValue: "pro gear", hiddenFields: ["brand"] },
          mockAddMeta
        )
      ).toBe(true);
    });

    it("does not match on multiple hidden fields", () => {
      const mockAddMeta = jest.fn();
      const hiddenFields = ["brand", "color", "nib"];

      // Brand is hidden
      expect(fuzzyMatch(input[0], null, { filterValue: "pilot", hiddenFields }, mockAddMeta)).toBe(
        false
      );

      // Color is hidden
      expect(fuzzyMatch(input[0], null, { filterValue: "amber", hiddenFields }, mockAddMeta)).toBe(
        false
      );

      // Nib is hidden
      expect(fuzzyMatch(input[3], null, { filterValue: "zoom", hiddenFields }, mockAddMeta)).toBe(
        false
      );

      // Model is still searchable
      expect(fuzzyMatch(input[1], null, { filterValue: "3776", hiddenFields }, mockAddMeta)).toBe(
        true
      );
    });
  });
});
