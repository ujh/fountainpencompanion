// @ts-check
import { fuzzyMatch, createFuzzyMatch } from "./match";

describe("fuzzyMatch", () => {
  const input = [
    {
      original: {
        brand_name: "Pilot",
        line_name: "Iroshizuku",
        ink_name: "Kon-peki",
        maker: "Pilot",
        comment: "Vivid blue, one of my faves",
        private_comment: "Bought at such and such for X amount",
        tags: []
      }
    },
    {
      original: {
        brand_name: "Pilot",
        line_name: "Iroshizuku",
        ink_name: "Shin-kai",
        maker: "Pilot",
        comment: "GOAT blue-black",
        private_comment: "The Pen Addict made me do it",
        tags: []
      }
    },
    {
      original: {
        brand_name: "Platinum",
        line_name: undefined,
        ink_name: "Carbon Black",
        maker: "Platinum",
        comment: "Perpetually inked in my Preppy",
        private_comment: "Cartridges bought at various points for about X amount per 4-pack",
        tags: []
      }
    },
    {
      original: {
        brand_name: "Sailor",
        line_name: "Manyo",
        ink_name: "Haha",
        maker: "Sailor",
        comment: undefined,
        private_comment: undefined,
        tags: []
      }
    }
  ];

  it("returns true for rows matching filter", () => {
    // Sailor rows should match "sail" filter
    expect(fuzzyMatch(input[3], null, "sail")).toBe(true);

    // Pilot row shouldn't match "sail"
    expect(fuzzyMatch(input[0], null, "sail")).toBe(false);

    // Platinum row shouldn't match "sail"
    expect(fuzzyMatch(input[2], null, "sail")).toBe(false);
  });

  it("returns true for exact matches in various fields", () => {
    // "manyo" should match the line_name field
    expect(fuzzyMatch(input[3], null, "manyo")).toBe(true);

    // "konpeki" should match the ink_name field
    expect(fuzzyMatch(input[0], null, "konpeki")).toBe(true);
  });

  it("returns true for partial fuzzy matches", () => {
    // "goat" should match comment "GOAT blue-black"
    expect(fuzzyMatch(input[1], null, "goat")).toBe(true);

    // "carb" should match "Carbon Black"
    expect(fuzzyMatch(input[2], null, "carb")).toBe(true);

    // "crb" should match "Carbon Black"
    expect(fuzzyMatch(input[2], null, "crb")).toBe(true);
  });

  it("returns false for non-matching filters", () => {
    // "xyz" should not match any row
    expect(fuzzyMatch(input[0], null, "xyz")).toBe(false);
    expect(fuzzyMatch(input[1], null, "xyz")).toBe(false);
    expect(fuzzyMatch(input[2], null, "xyz")).toBe(false);
    expect(fuzzyMatch(input[3], null, "xyz")).toBe(false);
  });

  it("returns true for empty filter", () => {
    // Empty filter should match all rows
    expect(fuzzyMatch(input[0], null, "")).toBe(true);
    expect(fuzzyMatch(input[1], null, "")).toBe(true);
    expect(fuzzyMatch(input[2], null, "")).toBe(true);
    expect(fuzzyMatch(input[3], null, "")).toBe(true);
  });

  it("searches across multiple fields", () => {
    // "iroshizuku" is in line_name
    expect(fuzzyMatch(input[0], null, "iroshizuku")).toBe(true);

    // "vivid" is in comment
    expect(fuzzyMatch(input[0], null, "vivid")).toBe(true);

    // "pen addict" is in private_comment
    expect(fuzzyMatch(input[1], null, "pen addict")).toBe(true);
  });

  it("handles undefined fields gracefully", () => {
    // Should not throw when undefined fields are present
    expect(() => fuzzyMatch(input[2], null, "carbon")).not.toThrow();
    expect(fuzzyMatch(input[2], null, "carbon")).toBe(true);
  });

  it("searches tags if present", () => {
    const rowWithTag = {
      original: {
        brand_name: "Test",
        line_name: "Test",
        ink_name: "Test Ink",
        maker: "Test",
        comment: "",
        private_comment: "",
        tags: [{ id: 1, name: "red" }]
      }
    };

    expect(fuzzyMatch(rowWithTag, null, "red")).toBe(true);
  });

  it("searches cluster_tags if present", () => {
    const rowWithClusterTags = {
      original: {
        brand_name: "Test",
        line_name: "Test",
        ink_name: "Test Ink",
        maker: "Test",
        comment: "",
        private_comment: "",
        tags: [],
        cluster_tags: ["sheen", "blue-black"]
      }
    };

    expect(fuzzyMatch(rowWithClusterTags, null, "sheen")).toBe(true);
  });
});

describe("createFuzzyMatch with hiddenFields", () => {
  const input = [
    {
      original: {
        brand_name: "Pilot",
        line_name: "Iroshizuku",
        ink_name: "Kon-peki",
        maker: "Pilot",
        comment: "Vivid blue, one of my faves",
        private_comment: "Bought at such and such for X amount",
        tags: [],
        cluster_tags: []
      }
    },
    {
      original: {
        brand_name: "Sailor",
        line_name: "Manyo",
        ink_name: "Haha",
        maker: "Sailor",
        comment: undefined,
        private_comment: undefined,
        tags: [],
        cluster_tags: []
      }
    }
  ];

  it("excludes hidden fields from search", () => {
    const match = createFuzzyMatch(["brand_name", "maker"]);
    // "sail" matches Sailor in brand_name and maker — both hidden
    expect(match(input[1], null, "sail")).toBe(false);
  });

  it("still matches on visible fields when some are hidden", () => {
    const match = createFuzzyMatch(["maker"]);
    // "Manyo" is in line_name which is still visible
    expect(match(input[1], null, "manyo")).toBe(true);
  });

  it("excludes comment from search when comment is hidden", () => {
    const match = createFuzzyMatch(["comment"]);
    // "Vivid" only appears in the comment of Kon-peki
    expect(match(input[0], null, "vivid")).toBe(false);

    // Without hiding comment it should match
    const matchAll = createFuzzyMatch([]);
    expect(matchAll(input[0], null, "vivid")).toBe(true);
  });

  it("excludes private_comment from search when private_comment is hidden", () => {
    const match = createFuzzyMatch(["private_comment"]);
    // "Pen Addict" only appears in the private_comment of Shin-kai-like row
    expect(match(input[0], null, "bought")).toBe(false);

    const matchAll = createFuzzyMatch([]);
    expect(matchAll(input[0], null, "bought")).toBe(true);
  });

  it("excludes tags from search when tags are hidden", () => {
    const rowWithTag = {
      original: {
        brand_name: "Test",
        line_name: "Test",
        ink_name: "Test Ink",
        maker: "Test",
        comment: "",
        private_comment: "",
        tags: [{ id: 1, name: "shimmering" }],
        cluster_tags: []
      }
    };

    const matchAll = createFuzzyMatch([]);
    expect(matchAll(rowWithTag, null, "shimmering")).toBe(true);

    const matchHiddenTags = createFuzzyMatch(["tags"]);
    expect(matchHiddenTags(rowWithTag, null, "shimmering")).toBe(false);
  });

  it("excludes cluster_tags from search when cluster_tags are hidden", () => {
    const rowWithClusterTags = {
      original: {
        brand_name: "Test",
        line_name: "Test",
        ink_name: "Test Ink",
        maker: "Test",
        comment: "",
        private_comment: "",
        tags: [],
        cluster_tags: ["sheen", "blue-black"]
      }
    };

    const matchAll = createFuzzyMatch([]);
    expect(matchAll(rowWithClusterTags, null, "sheen")).toBe(true);

    const matchHiddenCluster = createFuzzyMatch(["cluster_tags"]);
    expect(matchHiddenCluster(rowWithClusterTags, null, "sheen")).toBe(false);
  });

  it("returns true for empty filter regardless of hidden fields", () => {
    const match = createFuzzyMatch(["brand_name", "maker", "comment"]);
    expect(match(input[0], null, "")).toBe(true);
  });

  it("with no hidden fields behaves like the default fuzzyMatch", () => {
    const match = createFuzzyMatch([]);
    expect(match(input[0], null, "pilot")).toBe(fuzzyMatch(input[0], null, "pilot"));
    expect(match(input[1], null, "sailor")).toBe(fuzzyMatch(input[1], null, "sailor"));
    expect(match(input[0], null, "xyz")).toBe(fuzzyMatch(input[0], null, "xyz"));
  });
});
