// @ts-check
import { fuzzyMatch } from "./match";

describe("fuzzyMatch", () => {
  const input = [
    {
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
    },
    {
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
    },
    {
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
  ];

  it("matches and sorts by relevance", () => {
    expect(fuzzyMatch(input, "sail")).toStrictEqual([
      {
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
      },
      {
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
    ]);

    expect(fuzzyMatch(input, "carbon")).toStrictEqual([
      {
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
    ]);
  });

  it("handles an undefined filterValue", () => {
    expect(fuzzyMatch(input, undefined).length).toEqual(input.length);
  });

  it("does not match on hidden pen_name field", () => {
    // "Sailor" appears in pen_name for the first two entries
    // With pen_name hidden, searching "Pro Gear" (only in pen_name) should return nothing
    expect(fuzzyMatch(input, "Pro Gear", ["pen_name"])).toStrictEqual([]);
  });

  it("does not match on hidden comment field", () => {
    const inputWithComment = [
      ...input,
      {
        inked_on: "2023-01-15",
        archived_on: null,
        comment: "Great shading ink",
        last_used_on: null,
        pen_name: "TWSBI Eco, Clear, F",
        ink_name: "Diamine Oxblood - bottle",
        used_today: false,
        daily_usage: 0,
        refillable: true,
        unarchivable: false,
        archived: false
      }
    ];

    // "shading" only appears in comment
    expect(fuzzyMatch(inputWithComment, "shading", []).length).toEqual(1);
    expect(fuzzyMatch(inputWithComment, "shading", ["comment"])).toStrictEqual([]);
  });

  it("still matches on visible fields when others are hidden", () => {
    // "Sailor" appears in both pen_name and ink_name
    // With pen_name hidden, it should still match via ink_name
    const result = fuzzyMatch(input, "Sailor", ["pen_name"]);
    expect(result.length).toEqual(2);
  });

  it("still matches on ink_name when pen_name and comment are hidden", () => {
    // "carbon" appears only in ink_name which is not hideable
    expect(fuzzyMatch(input, "carbon", ["pen_name", "comment"]).length).toEqual(1);
  });
});
