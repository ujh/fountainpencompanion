import { withDistance } from "admin/pens-model-micro-clusters/withDistance";

describe("withDistance", () => {
  it("adds distance property to each macro cluster", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
      },
      {
        id: 2,
        brand: "Lamy",
        model: "Safari",
        grouped_entries: [{ brand: "Lamy", model: "Safari" }]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metro" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result).toHaveLength(2);
    expect(result[0]).toHaveProperty("distance");
    expect(result[1]).toHaveProperty("distance");
    expect(typeof result[0].distance).toBe("number");
    expect(typeof result[1].distance).toBe("number");
  });

  it("preserves all original macro cluster properties", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        additional_data: "test",
        created_at: "2023-01-01",
        grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metro" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0]).toEqual({
      id: 1,
      brand: "Pilot",
      model: "Metropolitan",
      additional_data: "test",
      created_at: "2023-01-01",
      grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }],
      distance: expect.any(Number)
    });
  });

  it("calculates lower distance for similar brands and models", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
      },
      {
        id: 2,
        brand: "Completely",
        model: "Different",
        grouped_entries: [{ brand: "Completely", model: "Different" }]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metro" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0].distance).toBeLessThan(result[1].distance);
  });

  it("returns distance of 0 for identical entries", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0].distance).toBe(0);
  });

  it("handles multiple grouped entries in macro cluster", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        grouped_entries: [
          { brand: "Pilot", model: "Metropolitan" },
          { brand: "Pilot", model: "Metro" }
        ]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metro" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0].distance).toBe(0);
  });

  it("handles multiple grouped entries in active cluster", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
      }
    ];

    const activeCluster = {
      grouped_entries: [
        { brand: "Pilot", model: "Metro" },
        { brand: "Pilot", model: "Metropolitan" }
      ]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0].distance).toBe(0);
  });

  it("includes macro cluster itself in distance calculation", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        grouped_entries: []
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0].distance).toBe(0);
  });

  it("handles empty grouped_entries in macro cluster", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        grouped_entries: []
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Lamy", model: "Safari" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0]).toHaveProperty("distance");
    expect(typeof result[0].distance).toBe("number");
  });

  it("handles empty grouped_entries in active cluster", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
      }
    ];

    const activeCluster = {
      grouped_entries: []
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0]).toHaveProperty("distance");
    expect(typeof result[0].distance).toBe("number");
  });

  it("handles strings with special characters and strips them correctly", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metro-politan (Special Edition)",
        grouped_entries: [{ brand: "Pilot", model: "Metro-politan (Special Edition)" }]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0]).toHaveProperty("distance");
    expect(typeof result[0].distance).toBe("number");
    expect(result[0].distance).toBeGreaterThanOrEqual(0);
    // Should be low distance because stripping should make them more similar
    expect(result[0].distance).toBeLessThan(5);
  });

  it("calculates distance between concatenated brand+model strings", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "PilotMetro", model: "politan" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0]).toHaveProperty("distance");
    expect(typeof result[0].distance).toBe("number");
    expect(result[0].distance).toBeGreaterThanOrEqual(0);
  });

  it("handles null/undefined brand and model values", () => {
    const macroClusters = [
      {
        id: 1,
        brand: null,
        model: undefined,
        grouped_entries: [{ brand: null, model: undefined }]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0]).toHaveProperty("distance");
    expect(typeof result[0].distance).toBe("number");
    expect(result[0].distance).toBeGreaterThan(0);
  });

  it("returns empty array when given empty macro clusters", () => {
    const macroClusters = [];
    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result).toEqual([]);
  });

  it("handles case where active cluster has null grouped_entries", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metropolitan",
        grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
      }
    ];

    const activeCluster = {
      grouped_entries: null
    };

    expect(() => withDistance(macroClusters, activeCluster)).toThrow();
  });

  it("finds minimum distance among multiple calculation methods", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "A",
        model: "B",
        grouped_entries: [{ brand: "A", model: "B" }]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "C", model: "D" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0].distance).toBeGreaterThan(0);
    expect(result[0].distance).toBeLessThan(Number.MAX_SAFE_INTEGER);
  });

  it("handles whitespace in brand and model names", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot ",
        model: " Metropolitan ",
        grouped_entries: [{ brand: "Pilot ", model: " Metropolitan " }]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    expect(result[0]).toHaveProperty("distance");
    expect(typeof result[0].distance).toBe("number");
    expect(result[0].distance).toBeGreaterThanOrEqual(0);
  });

  it("strips parentheses and hyphens correctly", () => {
    const macroClusters = [
      {
        id: 1,
        brand: "Pilot",
        model: "Metro-politan (Limited)",
        grouped_entries: [{ brand: "Pilot", model: "Metro-politan (Limited)" }]
      }
    ];

    const activeCluster = {
      grouped_entries: [{ brand: "Pilot", model: "Metropolitan" }]
    };

    const result = withDistance(macroClusters, activeCluster);

    // Should have low distance due to stripping
    expect(result[0].distance).toBeLessThan(3);
  });
});
