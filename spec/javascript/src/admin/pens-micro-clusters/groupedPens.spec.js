import { groupedPens } from "admin/pens-micro-clusters/groupedPens";

describe("groupedPens", () => {
  it("returns unique pens based on field values", () => {
    const collectedPens = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        color: "Black",
        material: "Metal",
        trim_color: "Silver",
        filling_system: "Cartridge",
        extra_field: "should_be_preserved"
      },
      {
        id: 2,
        brand: "Lamy",
        model: "Safari",
        color: "White",
        material: "Plastic",
        trim_color: "Silver",
        filling_system: "Cartridge"
      }
    ];

    const result = groupedPens(collectedPens);

    expect(result).toHaveLength(2);
    expect(result).toContainEqual(
      expect.objectContaining({
        id: 1,
        brand: "Pilot",
        model: "Metropolitan"
      })
    );
    expect(result).toContainEqual(
      expect.objectContaining({
        id: 2,
        brand: "Lamy",
        model: "Safari"
      })
    );
  });

  it("deduplicates pens with identical field values", () => {
    const collectedPens = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        color: "Black",
        material: "Metal",
        trim_color: "Silver",
        filling_system: "Cartridge"
      },
      {
        id: 2,
        brand: "Pilot",
        model: "Metropolitan",
        color: "Black",
        material: "Metal",
        trim_color: "Silver",
        filling_system: "Cartridge"
      },
      {
        id: 3,
        brand: "Lamy",
        model: "Safari",
        color: "White",
        material: "Plastic",
        trim_color: "Silver",
        filling_system: "Cartridge"
      }
    ];

    const result = groupedPens(collectedPens);

    expect(result).toHaveLength(2);
    // Should return the first pen from each group
    expect(result).toContainEqual(expect.objectContaining({ id: 1 }));
    expect(result).toContainEqual(expect.objectContaining({ id: 3 }));
    expect(result).not.toContainEqual(expect.objectContaining({ id: 2 }));
  });

  it("preserves all properties of the first pen in each group", () => {
    const collectedPens = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        color: "Black",
        material: "Metal",
        trim_color: "Silver",
        filling_system: "Cartridge",
        additional_data: "test",
        price: 25.99
      }
    ];

    const result = groupedPens(collectedPens);

    expect(result[0]).toEqual({
      id: 1,
      brand: "Pilot",
      model: "Metropolitan",
      color: "Black",
      material: "Metal",
      trim_color: "Silver",
      filling_system: "Cartridge",
      additional_data: "test",
      price: 25.99
    });
  });

  it("handles empty array", () => {
    const result = groupedPens([]);
    expect(result).toEqual([]);
  });

  it("handles pens with null/undefined field values", () => {
    const collectedPens = [
      {
        id: 1,
        brand: "Pilot",
        model: null,
        color: undefined,
        material: "Metal",
        trim_color: "",
        filling_system: "Cartridge"
      },
      {
        id: 2,
        brand: "Pilot",
        model: null,
        color: undefined,
        material: "Metal",
        trim_color: "",
        filling_system: "Cartridge"
      }
    ];

    const result = groupedPens(collectedPens);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual(expect.objectContaining({ id: 1 }));
  });

  it("groups by all field values correctly", () => {
    const collectedPens = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        color: "Black",
        material: "Metal",
        trim_color: "Silver",
        filling_system: "Cartridge"
      },
      {
        id: 2,
        brand: "Pilot", // Same brand
        model: "Metropolitan", // Same model
        color: "Blue", // Different color
        material: "Metal",
        trim_color: "Silver",
        filling_system: "Cartridge"
      }
    ];

    const result = groupedPens(collectedPens);

    // Should be considered different because color is different
    expect(result).toHaveLength(2);
  });

  it("handles single pen", () => {
    const collectedPens = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        color: "Black",
        material: "Metal",
        trim_color: "Silver",
        filling_system: "Cartridge"
      }
    ];

    const result = groupedPens(collectedPens);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual(collectedPens[0]);
  });
});
