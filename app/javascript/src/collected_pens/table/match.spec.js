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

  it("matches and sorts by relevance", () => {
    const mockAddMeta = jest.fn();

    // Test that Sailor rows match "sail" filter
    expect(fuzzyMatch(input[0], null, "sail", mockAddMeta)).toBe(false);
    expect(fuzzyMatch(input[1], null, "sail", mockAddMeta)).toBe(false);
    expect(fuzzyMatch(input[2], null, "sail", mockAddMeta)).toBe(true);
    expect(fuzzyMatch(input[3], null, "sail", mockAddMeta)).toBe(true);

    // Test that only Pilot row matches "amber" filter
    expect(fuzzyMatch(input[0], null, "amber", mockAddMeta)).toBe(true);
    expect(fuzzyMatch(input[1], null, "amber", mockAddMeta)).toBe(false);
    expect(fuzzyMatch(input[2], null, "amber", mockAddMeta)).toBe(false);
    expect(fuzzyMatch(input[3], null, "amber", mockAddMeta)).toBe(false);

    // Test that only Platinum row matches "3776" filter
    expect(fuzzyMatch(input[0], null, "3776", mockAddMeta)).toBe(false);
    expect(fuzzyMatch(input[1], null, "3776", mockAddMeta)).toBe(true);
    expect(fuzzyMatch(input[2], null, "3776", mockAddMeta)).toBe(false);
    expect(fuzzyMatch(input[3], null, "3776", mockAddMeta)).toBe(false);

    // Test that fuzzy matching works
    expect(fuzzyMatch(input[0], null, "spg", mockAddMeta)).toBe(false);
    expect(fuzzyMatch(input[1], null, "spg", mockAddMeta)).toBe(false);
    expect(fuzzyMatch(input[2], null, "spg", mockAddMeta)).toBe(true);
    expect(fuzzyMatch(input[3], null, "spg", mockAddMeta)).toBe(false);
  });
});
