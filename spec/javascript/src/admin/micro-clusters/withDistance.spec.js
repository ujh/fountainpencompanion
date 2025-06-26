import { withDistance } from "admin/micro-clusters/withDistance";

describe("withDistance", () => {
  it("calculates distances for macro clusters against active cluster", () => {
    const macroClusters = [
      {
        id: "1",
        brand_name: "Diamine",
        line_name: "Standard",
        ink_name: "Blue",
        grouped_entries: [
          {
            brand_name: "Diamine",
            line_name: "Standard",
            ink_name: "Blue"
          }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Diamine",
          line_name: "Standard",
          ink_name: "Blue"
        }
      ]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result).toHaveLength(1);
    expect(result[0]).toHaveProperty("distance");
    expect(result[0].distance).toBe(0); // Exact match should have distance 0
  });

  it("returns higher distance for different inks", () => {
    const macroClusters = [
      {
        id: "1",
        brand_name: "Pilot",
        line_name: "Iroshizuku",
        ink_name: "Kon-peki",
        grouped_entries: [
          {
            brand_name: "Pilot",
            line_name: "Iroshizuku",
            ink_name: "Kon-peki"
          }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Diamine",
          line_name: "Standard",
          ink_name: "Blue"
        }
      ]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0].distance).toBeGreaterThan(0);
  });

  it("handles multiple macro clusters", () => {
    const macroClusters = [
      {
        id: "1",
        brand_name: "Diamine",
        line_name: "Standard",
        ink_name: "Blue",
        grouped_entries: [
          {
            brand_name: "Diamine",
            line_name: "Standard",
            ink_name: "Blue"
          }
        ]
      },
      {
        id: "2",
        brand_name: "Pilot",
        line_name: "Iroshizuku",
        ink_name: "Kon-peki",
        grouped_entries: [
          {
            brand_name: "Pilot",
            line_name: "Iroshizuku",
            ink_name: "Kon-peki"
          }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Diamine",
          line_name: "Standard",
          ink_name: "Marine"
        }
      ]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result).toHaveLength(2);
    expect(result[0]).toHaveProperty("distance");
    expect(result[1]).toHaveProperty("distance");
  });

  it("includes macro cluster itself in comparison with grouped_entries", () => {
    const macroCluster = {
      id: "1",
      brand_name: "Diamine",
      line_name: "Standard",
      ink_name: "Blue",
      grouped_entries: []
    };

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Diamine",
          line_name: "Standard",
          ink_name: "Blue"
        }
      ]
    };

    const result = withDistance([macroCluster], activeCluster);

    expect(result[0].distance).toBe(0); // Should match the macro cluster itself
  });

  it("handles empty line names correctly", () => {
    const macroClusters = [
      {
        id: "1",
        brand_name: "Diamine",
        line_name: "",
        ink_name: "Blue",
        grouped_entries: [
          {
            brand_name: "Diamine",
            line_name: "",
            ink_name: "Blue"
          }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Diamine",
          line_name: "",
          ink_name: "Blue"
        }
      ]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0].distance).toBe(0);
  });

  it("handles missing line names for calc4 special case", () => {
    const macroClusters = [
      {
        id: "1",
        brand_name: "Diamine",
        line_name: "",
        ink_name: "Blue",
        grouped_entries: [
          {
            brand_name: "Diamine",
            line_name: "",
            ink_name: "Blue"
          }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Pilot",
          line_name: "",
          ink_name: "Black"
        }
      ]
    };

    const result = withDistance(macroClusters, activeCluster);

    // When both line names are empty, calc4 should return MAX_SAFE_INTEGER
    // but other calculations should still work
    expect(result[0].distance).toBeGreaterThan(0);
    expect(result[0].distance).toBeLessThan(Number.MAX_SAFE_INTEGER);
  });

  it("strips special characters correctly", () => {
    const macroClusters = [
      {
        id: "1",
        brand_name: "Noodler's",
        line_name: "",
        ink_name: "Blue-Black (Bulletproof)",
        grouped_entries: [
          {
            brand_name: "Noodler's",
            line_name: "",
            ink_name: "Blue-Black (Bulletproof)"
          }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Noodlers",
          line_name: "",
          ink_name: "BlueBlack"
        }
      ]
    };

    const result = withDistance(macroClusters, activeCluster);

    // Should have low distance due to character stripping
    expect(result[0].distance).toBeLessThan(3);
  });

  it("handles multiple entries in grouped_entries", () => {
    const macroClusters = [
      {
        id: "1",
        brand_name: "Diamine",
        line_name: "Standard",
        ink_name: "Blue",
        grouped_entries: [
          {
            brand_name: "Diamine",
            line_name: "Standard",
            ink_name: "Blue"
          },
          {
            brand_name: "Diamine",
            line_name: "Standard",
            ink_name: "Royal Blue"
          }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Diamine",
          line_name: "Standard",
          ink_name: "Royal Blue"
        }
      ]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0].distance).toBe(0); // Should match one of the entries exactly
  });

  it("preserves all original properties of macro clusters", () => {
    const macroClusters = [
      {
        id: "1",
        brand_name: "Diamine",
        line_name: "Standard",
        ink_name: "Blue",
        color: "#0000FF",
        custom_property: "test",
        grouped_entries: [
          {
            brand_name: "Diamine",
            line_name: "Standard",
            ink_name: "Blue"
          }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Pilot",
          line_name: "Iroshizuku",
          ink_name: "Kon-peki"
        }
      ]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0].id).toBe("1");
    expect(result[0].brand_name).toBe("Diamine");
    expect(result[0].line_name).toBe("Standard");
    expect(result[0].ink_name).toBe("Blue");
    expect(result[0].color).toBe("#0000FF");
    expect(result[0].custom_property).toBe("test");
    expect(result[0].grouped_entries).toEqual(macroClusters[0].grouped_entries);
  });

  it("finds minimum distance across all calculation methods", () => {
    const macroClusters = [
      {
        id: "1",
        brand_name: "Pilot",
        line_name: "Iroshizuku",
        ink_name: "Tsuki-yo",
        grouped_entries: [
          {
            brand_name: "Pilot",
            line_name: "Iroshizuku",
            ink_name: "Kon-peki"
          }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Waterman",
          line_name: "Classic",
          ink_name: "Blue"
        }
      ]
    };

    const result = withDistance(macroClusters, activeCluster);

    // Should find the minimum distance across calc1, calc2, calc3, calc4
    expect(result[0].distance).toBeGreaterThan(0);
    expect(result[0].distance).toBeLessThan(50); // Should be relatively small
  });

  it("handles undefined or null values by throwing an error", () => {
    const macroClusters = [
      {
        id: "1",
        brand_name: "Test Brand",
        line_name: null,
        ink_name: undefined,
        grouped_entries: [
          {
            brand_name: "Test Brand",
            line_name: null,
            ink_name: undefined
          }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        {
          brand_name: "Test Brand",
          line_name: "",
          ink_name: ""
        }
      ]
    };

    // Should throw an error when trying to process null/undefined values
    expect(() => withDistance(macroClusters, activeCluster)).toThrow();
  });

  it("handles empty arrays", () => {
    const result1 = withDistance([], {
      grouped_entries: [
        {
          brand_name: "Test",
          line_name: "Test",
          ink_name: "Test"
        }
      ]
    });

    const result2 = withDistance(
      [
        {
          id: "1",
          brand_name: "Test",
          line_name: "Test",
          ink_name: "Test",
          grouped_entries: []
        }
      ],
      {
        grouped_entries: []
      }
    );

    expect(result1).toEqual([]);
    expect(result2).toHaveLength(1);
  });
});
