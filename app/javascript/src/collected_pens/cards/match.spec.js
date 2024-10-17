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
    expect(fuzzyMatch(input, "sailor")).toStrictEqual([
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
});
