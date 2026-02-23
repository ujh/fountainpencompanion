// @ts-check
import { fuzzyFilter } from "./match";

describe("fuzzyFilter with composite filterValue", () => {
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

  it("matches when given a composite { text, hiddenFields } filterValue", () => {
    expect(fuzzyFilter(input[0], null, { text: "pilot", hiddenFields: [] })).toBe(true);
    expect(fuzzyFilter(input[1], null, { text: "sailor", hiddenFields: [] })).toBe(true);
  });

  it("returns true for empty text in composite filterValue", () => {
    expect(fuzzyFilter(input[0], null, { text: "", hiddenFields: [] })).toBe(true);
    expect(fuzzyFilter(input[0], null, { text: "", hiddenFields: ["brand_name"] })).toBe(true);
  });

  it("returns true for falsy filterValue", () => {
    expect(fuzzyFilter(input[0], null, null)).toBe(true);
    expect(fuzzyFilter(input[0], null, undefined)).toBe(true);
    expect(fuzzyFilter(input[0], null, "")).toBe(true);
  });

  it("falls back to plain string filterValue", () => {
    expect(fuzzyFilter(input[0], null, "pilot")).toBe(true);
    expect(fuzzyFilter(input[1], null, "sailor")).toBe(true);
    expect(fuzzyFilter(input[0], null, "xyz")).toBe(false);
  });

  it("excludes hidden fields from search via composite filterValue", () => {
    // "sailor" matches brand_name and maker
    expect(
      fuzzyFilter(input[1], null, { text: "sailor", hiddenFields: ["brand_name", "maker"] })
    ).toBe(false);
  });

  it("still matches on visible fields when some are hidden", () => {
    // "Manyo" is in line_name — hiding maker should still allow matching
    expect(fuzzyFilter(input[1], null, { text: "manyo", hiddenFields: ["maker"] })).toBe(true);
  });

  it("excludes comment from search when comment is hidden", () => {
    expect(fuzzyFilter(input[0], null, { text: "vivid", hiddenFields: [] })).toBe(true);
    expect(fuzzyFilter(input[0], null, { text: "vivid", hiddenFields: ["comment"] })).toBe(false);
  });

  it("excludes private_comment from search when private_comment is hidden", () => {
    expect(fuzzyFilter(input[0], null, { text: "bought", hiddenFields: [] })).toBe(true);
    expect(fuzzyFilter(input[0], null, { text: "bought", hiddenFields: ["private_comment"] })).toBe(
      false
    );
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

    expect(fuzzyFilter(rowWithTag, null, { text: "shimmering", hiddenFields: [] })).toBe(true);
    expect(fuzzyFilter(rowWithTag, null, { text: "shimmering", hiddenFields: ["tags"] })).toBe(
      false
    );
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

    expect(fuzzyFilter(rowWithClusterTags, null, { text: "sheen", hiddenFields: [] })).toBe(true);
    expect(
      fuzzyFilter(rowWithClusterTags, null, { text: "sheen", hiddenFields: ["cluster_tags"] })
    ).toBe(false);
  });

  it("correctly filters with hidden comment field", () => {
    expect(fuzzyFilter(input[0], null, { text: "pilot", hiddenFields: ["comment"] })).toBe(true);
    expect(fuzzyFilter(input[0], null, { text: "vivid", hiddenFields: ["comment"] })).toBe(false);
  });
});
