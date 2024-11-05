// @ts-check
import { fuzzyMatch } from "./match";

describe("fuzzyMatch", () => {
  const input = [
    {
      values: {
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
      values: {
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
      values: {
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
      values: {
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
    expect(fuzzyMatch(input, null, "sail")).toStrictEqual([
      {
        values: {
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
        values: {
          brand: "Sailor",
          model: "Profit Casual",
          nib: "Zoom",
          color: "Red",
          comment: "",
          usage: 1,
          daily_usage: 0
        }
      }
    ]);

    expect(fuzzyMatch(input, null, "amber")).toStrictEqual([
      {
        values: {
          brand: "Pilot",
          model: "Custom 823",
          nib: "M",
          color: "Amber",
          comment: "",
          usage: 1,
          daily_usage: 0
        }
      }
    ]);

    expect(fuzzyMatch(input, null, "3776")).toStrictEqual([
      {
        values: {
          brand: "Platinum",
          model: "#3776 Century",
          nib: "F",
          color: "Black Diamond",
          comment: "",
          usage: 1,
          daily_usage: 1
        }
      }
    ]);
  });
});
