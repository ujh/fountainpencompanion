// @ts-check
import { fuzzyMatch } from "./match";

describe("fuzzyMatch", () => {
  const input = [
    {
      original: {
        inked_on: "2023-01-15",
        archived_on: null,
        comment: "",
        last_used_on: null,
        pen_name: "Sailor Profit Casual, Red, Zoom, ground to an architect by Such N'Such",
        ink_name: "Sailor Shikiori Yozakura - bottle",
        used_today: false,
        daily_usage: 0,
        refillable: true,
        unarchivable: false,
        archived: false
      }
    },
    {
      original: {
        inked_on: "2023-01-15",
        archived_on: null,
        comment: "Great shading ink",
        last_used_on: "2023-02-04",
        pen_name: "Sailor Pro Gear, Black, M",
        ink_name: "Sailor Shikiori Yozakura - bottle",
        used_today: false,
        daily_usage: 1,
        refillable: true,
        unarchivable: false,
        archived: false
      }
    },
    {
      original: {
        inked_on: "2023-01-15",
        archived_on: null,
        comment: "",
        last_used_on: "2023-02-04",
        pen_name: "Platinum #3776 Century, Black Diamond, F",
        ink_name: "Platinum Carbon Black - cartridge",
        used_today: false,
        daily_usage: 1,
        refillable: true,
        unarchivable: false,
        archived: false
      }
    }
  ];

  describe("with a plain string filterValue", () => {
    it("matches and sorts by relevance", () => {
      const mockAddMeta = jest.fn();

      // Test that Sailor rows match "sail" filter
      expect(fuzzyMatch(input[0], null, "sail", mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[1], null, "sail", mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[2], null, "sail", mockAddMeta)).toBe(false);

      // Test that only Platinum row matches "carbon" filter
      expect(fuzzyMatch(input[0], null, "carbon", mockAddMeta)).toBe(false);
      expect(fuzzyMatch(input[1], null, "carbon", mockAddMeta)).toBe(false);
      expect(fuzzyMatch(input[2], null, "carbon", mockAddMeta)).toBe(true);

      // Test fuzzy matching with "slr"
      expect(fuzzyMatch(input[0], null, "slr", mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[1], null, "slr", mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[2], null, "slr", mockAddMeta)).toBe(false);
    });
  });

  describe("with a structured filterValue and no hidden fields", () => {
    it("behaves the same as a plain string filterValue", () => {
      const mockAddMeta = jest.fn();

      expect(fuzzyMatch(input[0], null, { text: "sail", hiddenFields: [] }, mockAddMeta)).toBe(
        true
      );
      expect(fuzzyMatch(input[1], null, { text: "sail", hiddenFields: [] }, mockAddMeta)).toBe(
        true
      );
      expect(fuzzyMatch(input[2], null, { text: "sail", hiddenFields: [] }, mockAddMeta)).toBe(
        false
      );

      expect(fuzzyMatch(input[0], null, { text: "carbon", hiddenFields: [] }, mockAddMeta)).toBe(
        false
      );
      expect(fuzzyMatch(input[2], null, { text: "carbon", hiddenFields: [] }, mockAddMeta)).toBe(
        true
      );
    });
  });

  describe("with hidden fields", () => {
    it("does not match on hidden pen_name field", () => {
      const mockAddMeta = jest.fn();

      // "Pro Gear" only appears in pen_name, so hiding it should prevent a match
      expect(
        fuzzyMatch(input[1], null, { text: "Pro Gear", hiddenFields: ["pen_name"] }, mockAddMeta)
      ).toBe(false);
    });

    it("does not match on hidden comment field", () => {
      const mockAddMeta = jest.fn();

      // "shading" only appears in comment of input[1]
      expect(
        fuzzyMatch(input[1], null, { text: "shading", hiddenFields: ["comment"] }, mockAddMeta)
      ).toBe(false);
    });

    it("still matches on visible fields when others are hidden", () => {
      const mockAddMeta = jest.fn();

      // "Sailor" appears in ink_name too, so it should still match with pen_name hidden
      expect(
        fuzzyMatch(input[0], null, { text: "Sailor", hiddenFields: ["pen_name"] }, mockAddMeta)
      ).toBe(true);
      expect(
        fuzzyMatch(input[1], null, { text: "Sailor", hiddenFields: ["pen_name"] }, mockAddMeta)
      ).toBe(true);
    });

    it("still matches on ink_name when pen_name and comment are hidden", () => {
      const mockAddMeta = jest.fn();
      const filterValue = { text: "carbon", hiddenFields: ["pen_name", "comment"] };

      // "carbon" appears only in ink_name which is not hideable
      expect(fuzzyMatch(input[2], null, filterValue, mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[0], null, filterValue, mockAddMeta)).toBe(false);
    });

    it("defaults to no hidden fields when hiddenFields is omitted from the object", () => {
      const mockAddMeta = jest.fn();

      // Should behave like no hidden fields
      expect(fuzzyMatch(input[0], null, { text: "sail" }, mockAddMeta)).toBe(true);
      expect(fuzzyMatch(input[2], null, { text: "sail" }, mockAddMeta)).toBe(false);
    });
  });
});
