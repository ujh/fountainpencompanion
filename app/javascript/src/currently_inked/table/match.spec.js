// @ts-check
import { fuzzyMatch } from "./match";

describe("fuzzyMatch", () => {
  const input = [
    {
      values: {
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
      values: {
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
      values: {
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
    expect(fuzzyMatch(input, null, "sail")).toStrictEqual([
      {
        values: {
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
        values: {
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
      }
    ]);

    expect(fuzzyMatch(input, null, "carbon")).toStrictEqual([
      {
        values: {
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
    ]);
  });
});
