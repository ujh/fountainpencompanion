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
        comment: "",
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

    // Test that only Platinum row matches "carbon" filter
    expect(fuzzyMatch(input[0], null, "slr", mockAddMeta)).toBe(true);
    expect(fuzzyMatch(input[1], null, "slr", mockAddMeta)).toBe(true);
    expect(fuzzyMatch(input[2], null, "slr", mockAddMeta)).toBe(false);
  });
});
