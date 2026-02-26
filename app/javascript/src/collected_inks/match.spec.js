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
      private_comment: "Cartridges bought at various points for about X amount per 4-pack"
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
        private_comment: "Cartridges bought at various points for about X amount per 4-pack"
      }
    ]);

    expect(fuzzyMatch(input, "carb")).toStrictEqual([
      {
        brand_name: "Platinum",
        line_name: undefined,
        ink_name: "Carbon Black",
        maker: "Platinum",
        comment: "Perpetually inked in my Preppy",
        private_comment: "Cartridges bought at various points for about X amount per 4-pack"
      }
    ]);
  });

  it("handles an undefined filterValue", () => {
    expect(fuzzyMatch(input, undefined).length).toEqual(input.length);
  });

  it("excludes hidden fields from search", () => {
    // "sailor" matches Sailor in brand_name and maker
    // When brand_name and maker are hidden, "sailor" should not match
    expect(fuzzyMatch(input, "sailor", ["brand_name", "maker"]).length).toEqual(0);
  });

  it("still matches on visible fields when some are hidden", () => {
    // "Manyo" is in line_name — hiding maker should still allow matching on line_name
    const results = fuzzyMatch(input, "many", ["maker"]);
    expect(results.length).toBeGreaterThanOrEqual(1);
    expect(results[0].line_name).toEqual("Manyo");
  });

  it("excludes comment from search when comment is hidden", () => {
    // "Vivid" only appears in the comment of Kon-peki
    expect(fuzzyMatch(input, "vivid", []).length).toEqual(1);
    expect(fuzzyMatch(input, "vivid", ["comment"]).length).toEqual(0);
  });

  it("excludes private_comment from search when private_comment is hidden", () => {
    // "Pen Addict" only appears in the private_comment of Shin-kai
    expect(fuzzyMatch(input, "penaddict", []).length).toEqual(1);
    expect(fuzzyMatch(input, "penaddict", ["private_comment"]).length).toEqual(0);
  });

  it("excludes tags from search when tags are hidden", () => {
    const inputWithTags = [
      {
        brand_name: "Test",
        line_name: "Test",
        ink_name: "Test Ink",
        maker: "Test",
        comment: "",
        private_comment: "",
        tags: [{ id: 1, name: "shimmering" }]
      }
    ];

    // With tags visible, "shimmering" matches
    expect(fuzzyMatch(inputWithTags, "shimmering", []).length).toEqual(1);
    // With tags hidden, "shimmering" does not match
    expect(fuzzyMatch(inputWithTags, "shimmering", ["tags"]).length).toEqual(0);
  });

  it("searches cluster_tags when not hidden", () => {
    const inputWithClusterTags = [
      {
        brand_name: "Test",
        line_name: "Test",
        ink_name: "Test Ink",
        maker: "Test",
        comment: "",
        private_comment: "",
        tags: [],
        cluster_tags: ["sheen", "blue-black"]
      }
    ];

    // With cluster_tags visible, "sheen" matches
    expect(fuzzyMatch(inputWithClusterTags, "sheen", []).length).toEqual(1);
    // With cluster_tags hidden, "sheen" does not match
    expect(fuzzyMatch(inputWithClusterTags, "sheen", ["cluster_tags"]).length).toEqual(0);
  });

  it("defaults hiddenFields to empty array", () => {
    // Calling without hiddenFields should work the same as before
    expect(fuzzyMatch(input, "sail")).toStrictEqual(fuzzyMatch(input, "sail", []));
  });
});
