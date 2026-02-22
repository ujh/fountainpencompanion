// @ts-check
import { fuzzyMatch } from "./match";

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
});
