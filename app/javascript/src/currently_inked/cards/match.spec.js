// @ts-check
import { fuzzyMatch } from "./match";

describe("fuzzyMatch", () => {
  const input = [
    {
      inked_on: "2023-01-15",
      archived_on: null,
      comment: "",
      last_used_on: null,
      pen_name:
        "Sailor Profit Casual, Red, Zoom, ground to an architect by Such N'Such",
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
        pen_name:
          "Sailor Profit Casual, Red, Zoom, ground to an architect by Such N'Such",
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
});
