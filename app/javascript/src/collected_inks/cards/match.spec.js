// @ts-check
import { fuzzyMatch } from "./match";

describe("fuzzyMatch", () => {
  const input = [
    {
      brand_name: "Pilot",
      line_name: "Iroshizuku",
      ink_name: "Kon-peki",
      maker: "Pilot",
      comment: "Vivid blue, one of my faves",
      private_comment: "Bought at such and such for X amount"
    },
    {
      brand_name: "Pilot",
      line_name: "Iroshizuku",
      ink_name: "Shin-kai",
      maker: "Pilot",
      comment: "GOAT blue-black",
      private_comment: "The Pen Addict made me do it"
    },
    {
      brand_name: "Platinum",
      line_name: undefined,
      ink_name: "Carbon Black",
      maker: "Platinum",
      comment: "Perpetually inked in my Preppy",
      private_comment:
        "Cartridges bought at various points for about X amount per 4-pack"
    },
    {
      brand_name: "Sailor",
      line_name: "Manyo",
      ink_name: "Haha",
      maker: "Sailor",
      comment: undefined,
      private_comment: undefined
    }
  ];

  it("matches and sorts by relevance", () => {
    expect(fuzzyMatch(input, "sail")).toStrictEqual([
      {
        brand_name: "Sailor",
        line_name: "Manyo",
        ink_name: "Haha",
        maker: "Sailor",
        comment: undefined,
        private_comment: undefined
      },
      {
        brand_name: "Pilot",
        line_name: "Iroshizuku",
        ink_name: "Shin-kai",
        maker: "Pilot",
        comment: "GOAT blue-black",
        private_comment: "The Pen Addict made me do it"
      },
      {
        brand_name: "Platinum",
        line_name: undefined,
        ink_name: "Carbon Black",
        maker: "Platinum",
        comment: "Perpetually inked in my Preppy",
        private_comment:
          "Cartridges bought at various points for about X amount per 4-pack"
      }
    ]);

    expect(fuzzyMatch(input, "many")).toStrictEqual([
      {
        brand_name: "Sailor",
        line_name: "Manyo",
        ink_name: "Haha",
        maker: "Sailor",
        comment: undefined,
        private_comment: undefined
      },
      {
        brand_name: "Platinum",
        line_name: undefined,
        ink_name: "Carbon Black",
        maker: "Platinum",
        comment: "Perpetually inked in my Preppy",
        private_comment:
          "Cartridges bought at various points for about X amount per 4-pack"
      },
      {
        brand_name: "Pilot",
        line_name: "Iroshizuku",
        ink_name: "Kon-peki",
        maker: "Pilot",
        comment: "Vivid blue, one of my faves",
        private_comment: "Bought at such and such for X amount"
      }
    ]);

    expect(fuzzyMatch(input, "carb")).toStrictEqual([
      {
        brand_name: "Platinum",
        line_name: undefined,
        ink_name: "Carbon Black",
        maker: "Platinum",
        comment: "Perpetually inked in my Preppy",
        private_comment:
          "Cartridges bought at various points for about X amount per 4-pack"
      },
      {
        brand_name: "Pilot",
        line_name: "Iroshizuku",
        ink_name: "Kon-peki",
        maker: "Pilot",
        comment: "Vivid blue, one of my faves",
        private_comment: "Bought at such and such for X amount"
      }
    ]);
  });

  it("handles an undefined filterValue", () => {
    expect(fuzzyMatch(input, undefined).length).toEqual(input.length);
  });
});
