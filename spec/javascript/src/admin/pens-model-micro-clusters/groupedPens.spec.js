import { groupedPens } from "admin/pens-model-micro-clusters/groupedPens";

describe("groupedPens", () => {
  it("returns unique pens grouped by brand and model", () => {
    const modelVariants = [
      { brand: "Pilot", model: "Metropolitan", color: "Black", id: 1 },
      { brand: "Pilot", model: "Metropolitan", color: "Red", id: 2 },
      { brand: "Lamy", model: "Safari", color: "Blue", id: 3 },
      { brand: "Lamy", model: "Safari", color: "Green", id: 4 }
    ];

    const result = groupedPens(modelVariants);

    expect(result).toHaveLength(2);
    expect(result).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ brand: "Pilot", model: "Metropolitan" }),
        expect.objectContaining({ brand: "Lamy", model: "Safari" })
      ])
    );
  });

  it("returns the first item from each group", () => {
    const modelVariants = [
      { brand: "Pilot", model: "Metropolitan", color: "Black", id: 1 },
      { brand: "Pilot", model: "Metropolitan", color: "Red", id: 2 },
      { brand: "Pilot", model: "Metropolitan", color: "Blue", id: 3 }
    ];

    const result = groupedPens(modelVariants);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({ brand: "Pilot", model: "Metropolitan", color: "Black", id: 1 });
  });

  it("handles different brands with same model", () => {
    const modelVariants = [
      { brand: "Pilot", model: "Metropolitan", color: "Black", id: 1 },
      { brand: "Lamy", model: "Metropolitan", color: "Red", id: 2 }
    ];

    const result = groupedPens(modelVariants);

    expect(result).toHaveLength(2);
    expect(result).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ brand: "Pilot", model: "Metropolitan" }),
        expect.objectContaining({ brand: "Lamy", model: "Metropolitan" })
      ])
    );
  });

  it("handles same brand with different models", () => {
    const modelVariants = [
      { brand: "Pilot", model: "Metropolitan", color: "Black", id: 1 },
      { brand: "Pilot", model: "Custom", color: "Red", id: 2 }
    ];

    const result = groupedPens(modelVariants);

    expect(result).toHaveLength(2);
    expect(result).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ brand: "Pilot", model: "Metropolitan" }),
        expect.objectContaining({ brand: "Pilot", model: "Custom" })
      ])
    );
  });

  it("returns empty array when given empty array", () => {
    const result = groupedPens([]);

    expect(result).toEqual([]);
  });

  it("handles single item", () => {
    const modelVariants = [{ brand: "Pilot", model: "Metropolitan", color: "Black", id: 1 }];

    const result = groupedPens(modelVariants);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({ brand: "Pilot", model: "Metropolitan", color: "Black", id: 1 });
  });

  it("preserves all properties of the first item in each group", () => {
    const modelVariants = [
      { brand: "Pilot", model: "Metropolitan", color: "Black", id: 1, nib: "M", extra: "data" },
      { brand: "Pilot", model: "Metropolitan", color: "Red", id: 2, nib: "F", extra: "other" }
    ];

    const result = groupedPens(modelVariants);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      brand: "Pilot",
      model: "Metropolitan",
      color: "Black",
      id: 1,
      nib: "M",
      extra: "data"
    });
  });

  it("handles items with missing brand or model fields", () => {
    const modelVariants = [
      { brand: "Pilot", model: undefined, color: "Black", id: 1 },
      { brand: null, model: "Metropolitan", color: "Red", id: 2 },
      { brand: "Lamy", model: "Safari", color: "Blue", id: 3 }
    ];

    const result = groupedPens(modelVariants);

    expect(result).toHaveLength(3);
    expect(result).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ brand: "Pilot", model: undefined }),
        expect.objectContaining({ brand: null, model: "Metropolitan" }),
        expect.objectContaining({ brand: "Lamy", model: "Safari" })
      ])
    );
  });

  it("groups items with identical brand and model regardless of case", () => {
    const modelVariants = [
      { brand: "Pilot", model: "Metropolitan", color: "Black", id: 1 },
      { brand: "Pilot", model: "Metropolitan", color: "Red", id: 2 }
    ];

    const result = groupedPens(modelVariants);

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe(1);
  });

  it("handles empty strings, null, and undefined values", () => {
    const modelVariants = [
      { brand: "", model: "Metropolitan", color: "Black", id: 1 },
      { brand: null, model: "Metropolitan", color: "Red", id: 2 },
      { brand: undefined, model: "Metropolitan", color: "Blue", id: 3 }
    ];

    const result = groupedPens(modelVariants);

    // All three items should be grouped together since null, undefined, and empty string
    // all convert to empty string when joined, creating the same grouping key
    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({ brand: "", model: "Metropolitan", color: "Black", id: 1 });
  });
});
