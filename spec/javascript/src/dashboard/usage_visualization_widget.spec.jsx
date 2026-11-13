import { render, screen } from "@testing-library/react";
import {
  UsageVisualizationWidget,
  buildGrid,
  computeCenters,
  computeColorWeights,
  createPalette,
  createVoronoiRenderer,
  gaussianKernel,
  simulationTick
} from "dashboard/usage_visualization_widget";
import { HttpResponse, http } from "msw";
import { setupServer } from "msw/node";

beforeAll(() => {
  global.IntersectionObserver = class {
    constructor(cb) {
      this.cb = cb;
    }
    observe() {
      this.cb([{ isIntersecting: true }]);
    }
    disconnect() {}
  };
});

const widgetData = (entries = [], source = "usage_records", totalCount = 0) => ({
  data: {
    type: "widget",
    id: "usage_visualization",
    attributes: { entries, source, total_count: totalCount }
  }
});

const accountData = {
  data: { attributes: { preferences: {} } }
};

describe("UsageVisualizationWidget", () => {
  const server = setupServer(
    http.get("/dashboard/widgets/usage_visualization.json", () => {
      return HttpResponse.json(
        widgetData(
          [
            { ink_name: "Pilot Blue", color: "#0000ff", count: 5 },
            { ink_name: "Diamine Red", color: "#ff0000", count: 3 }
          ],
          "usage_records",
          15
        )
      );
    }),
    http.get("/account", () => {
      return HttpResponse.json(accountData);
    }),
    http.put("/account", () => {
      return HttpResponse.json({});
    })
  );

  beforeAll(() => server.listen());
  afterEach(() => {
    server.resetHandlers();
    localStorage.clear();
  });
  afterAll(() => server.close());

  it("renders a canvas when data is present", async () => {
    render(<UsageVisualizationWidget renderWhenInvisible />);
    // Wait for data to load by finding the range picker first
    await screen.findByDisplayValue("1 year");
    const canvas = document.querySelector(".fpc-usage-visualization__canvas");
    expect(canvas).toBeTruthy();
    expect(canvas.tagName).toBe("CANVAS");
  });

  it("renders a label below the canvas", async () => {
    render(<UsageVisualizationWidget renderWhenInvisible />);
    await screen.findByDisplayValue("1 year");
    const label = document.querySelector(".fpc-usage-visualization__label");
    expect(label).toBeTruthy();
    expect(label.textContent).toBe("\u00A0");
  });

  it("renders range picker select", async () => {
    render(<UsageVisualizationWidget renderWhenInvisible />);
    const select = await screen.findByDisplayValue("1 year");
    expect(select.tagName).toBe("SELECT");
    expect(select.options.length).toBe(5);
  });

  it("shows empty message when no data", async () => {
    server.use(
      http.get("/dashboard/widgets/usage_visualization.json", () => {
        return HttpResponse.json(widgetData([], "insufficient", 0));
      })
    );

    render(<UsageVisualizationWidget renderWhenInvisible />);
    await screen.findByText(/Not enough usage data yet/);
  });

  it("shows fallback message when using currently inked data", async () => {
    server.use(
      http.get("/dashboard/widgets/usage_visualization.json", () => {
        return HttpResponse.json(
          widgetData([{ ink_name: "Pilot Blue", color: "#0000ff", count: 6 }], "currently_inked", 5)
        );
      })
    );

    render(<UsageVisualizationWidget renderWhenInvisible />);
    await screen.findByText(/Based on currently inked pens/);
  });
});

describe("buildGrid", () => {
  it("returns empty arrays when totalCount is zero", () => {
    const result = buildGrid([], 4, 4);
    expect(result.grid).toEqual([]);
    expect(result.inkInfo).toEqual([]);
  });

  it("creates grid with correct total pixels", () => {
    const entries = [
      { ink_name: "Ink A", color: "#ff0000", count: 3, ink_id: 10 },
      { ink_name: "Ink B", color: "#0000ff", count: 1, ink_id: 20 }
    ];
    const { grid, inkInfo } = buildGrid(entries, 4, 4);
    expect(grid.length).toBe(16);
    expect(inkInfo.length).toBe(16);
  });

  it("distributes pixels proportionally by count", () => {
    const entries = [
      { ink_name: "Ink A", color: "#ff0000", count: 3, ink_id: 10 },
      { ink_name: "Ink B", color: "#0000ff", count: 1, ink_id: 20 }
    ];
    const { grid } = buildGrid(entries, 4, 4);
    const redCount = grid.filter((c) => c === "#ff0000").length;
    const blueCount = grid.filter((c) => c === "#0000ff").length;
    expect(redCount).toBe(12);
    expect(blueCount).toBe(4);
  });

  it("populates inkInfo with name and inkId", () => {
    const entries = [{ ink_name: "Pilot Blue", color: "#0000ff", count: 1, ink_id: 42 }];
    const { inkInfo } = buildGrid(entries, 2, 2);
    expect(inkInfo.length).toBe(4);
    inkInfo.forEach((info) => {
      expect(info.name).toBe("Pilot Blue");
      expect(info.inkId).toBe(42);
    });
  });

  it("sets inkId to null when not provided", () => {
    const entries = [{ ink_name: "Unknown Ink", color: "#000000", count: 1 }];
    const { inkInfo } = buildGrid(entries, 2, 2);
    inkInfo.forEach((info) => {
      expect(info.inkId).toBeNull();
    });
  });

  it("shuffles the grid", () => {
    const entries = [
      { ink_name: "A", color: "#ff0000", count: 50, ink_id: 1 },
      { ink_name: "B", color: "#0000ff", count: 50, ink_id: 2 }
    ];
    // With 100 pixels of two colors, an unshuffled grid would have all red first then blue.
    // After shuffle it's extremely unlikely to stay sorted. Run multiple times to reduce flakiness.
    const { grid } = buildGrid(entries, 10, 10);
    const firstHalf = grid.slice(0, 50);
    const allSameColor = firstHalf.every((c) => c === firstHalf[0]);
    expect(allSameColor).toBe(false);
  });

  it("fills exactly cols * rows cells when rounded shares add up to more", () => {
    const entries = Array.from({ length: 10 }, (_, i) => ({
      ink_name: `Ink ${i}`,
      color: `#00000${i}`,
      count: 1
    }));
    const { grid, inkInfo } = buildGrid(entries, 4, 4);
    expect(grid.length).toBe(16);
    expect(inkInfo.length).toBe(16);
    for (const entry of entries) {
      const cells = grid.filter((c) => c === entry.color).length;
      expect(cells === 1 || cells === 2).toBe(true);
    }
  });

  it("keeps grid and inkInfo in sync after shuffle", () => {
    const entries = [
      { ink_name: "Red Ink", color: "#ff0000", count: 5, ink_id: 1 },
      { ink_name: "Blue Ink", color: "#0000ff", count: 5, ink_id: 2 }
    ];
    const { grid, inkInfo } = buildGrid(entries, 5, 2);
    for (let i = 0; i < grid.length; i++) {
      if (grid[i] === "#ff0000") {
        expect(inkInfo[i].name).toBe("Red Ink");
        expect(inkInfo[i].inkId).toBe(1);
      } else {
        expect(inkInfo[i].name).toBe("Blue Ink");
        expect(inkInfo[i].inkId).toBe(2);
      }
    }
  });
});

const randomColor = (i) => `#${((i * 2654435761) >>> 8).toString(16).padStart(6, "0").slice(-6)}`;

const manyInks = (n) =>
  Array.from({ length: n }, (_, i) => ({
    ink_name: `Ink ${i}`,
    ink_id: i,
    color: randomColor(i),
    count: Math.ceil(100 / (i + 1))
  }));

const tick = (entries, cells, inkInfo, size, multiplier) => {
  const { colors } = createPalette(entries);
  const centers = computeCenters(cells, size, colors.length, computeColorWeights(colors));
  return simulationTick(cells, inkInfo, size, size, centers, multiplier);
};

const shuffledCells = (entries, size) => {
  const { grid, inkInfo } = buildGrid(entries, size, size);
  return { cells: createPalette(entries).toCells(grid), inkInfo };
};

describe("simulationTick", () => {
  it("is not converged on a shuffled grid at slow speed", () => {
    const entries = manyInks(10);
    const { cells, inkInfo } = shuffledCells(entries, 140);
    expect(tick(entries, cells, inkInfo, 140, 1).converged).toBe(false);
  });

  it("is not converged on a shuffled grid with hundreds of inks", () => {
    const entries = manyInks(230);
    const { cells, inkInfo } = shuffledCells(entries, 140);
    expect(tick(entries, cells, inkInfo, 140, 6).converged).toBe(false);
  });

  it("is converged when each color already forms one block", () => {
    const entries = [
      { ink_name: "Red", color: "#ff0000", count: 1 },
      { ink_name: "Blue", color: "#0000ff", count: 1 }
    ];
    const cells = Int32Array.from({ length: 140 * 140 }, (_, i) =>
      Math.floor(i / 140) < 70 ? 0 : 1
    );
    const inkInfo = Array.from(cells, (color) => ({ name: entries[color].ink_name, inkId: null }));
    expect(tick(entries, cells, inkInfo, 140, 1).converged).toBe(true);
  });
});

describe("createPalette", () => {
  it("maps each distinct color to one index", () => {
    const entries = [
      { ink_name: "A", color: "#ff0000", count: 1 },
      { ink_name: "B", color: "#0000ff", count: 1 },
      { ink_name: "C", color: "#ff0000", count: 1 }
    ];
    const palette = createPalette(entries);
    expect(palette.colors).toEqual(["#ff0000", "#0000ff"]);
    expect(Array.from(palette.toCells(["#0000ff", "#ff0000", "#ff0000"]))).toEqual([1, 0, 0]);
  });
});

describe("createVoronoiRenderer", () => {
  const kernel = gaussianKernel(2);
  const pixelColor = (data, width, x, y) => {
    const off = (y * width + x) * 4;
    return [data[off], data[off + 1], data[off + 2]];
  };

  it("paints a single-color grid in that color", () => {
    const renderer = createVoronoiRenderer(["#ff0000"], 10, 10, 2, kernel);
    const data = new Uint8ClampedArray(renderer.width * renderer.height * 4);
    renderer.render(new Int32Array(100), data);
    for (let y = 0; y < renderer.height; y++) {
      for (let x = 0; x < renderer.width; x++) {
        expect(pixelColor(data, renderer.width, x, y)).toEqual([255, 0, 0]);
      }
    }
  });

  it("smooths away a single cell surrounded by another color", () => {
    const renderer = createVoronoiRenderer(["#ff0000", "#0000ff"], 10, 10, 2, kernel);
    const data = new Uint8ClampedArray(renderer.width * renderer.height * 4);
    const cells = new Int32Array(100);
    cells[55] = 1;
    renderer.render(cells, data);
    expect(pixelColor(data, renderer.width, 10, 10)).toEqual([255, 0, 0]);
  });

  it("keeps a block of another color", () => {
    const renderer = createVoronoiRenderer(["#ff0000", "#0000ff"], 10, 10, 2, kernel);
    const data = new Uint8ClampedArray(renderer.width * renderer.height * 4);
    const cells = Int32Array.from({ length: 100 }, (_, i) => (i % 10 < 5 ? 0 : 1));
    renderer.render(cells, data);
    expect(pixelColor(data, renderer.width, 4, 4)).toEqual([255, 0, 0]);
    expect(pixelColor(data, renderer.width, 14, 4)).toEqual([0, 0, 255]);
  });

  it("paints the same image after updates as a fresh render of the final grid", () => {
    const entries = manyInks(20);
    const { colors } = createPalette(entries);
    const { cells, inkInfo } = shuffledCells(entries, 30);
    const updated = createVoronoiRenderer(colors, 30, 30, 2, kernel);
    const data = new Uint8ClampedArray(updated.width * updated.height * 4);
    updated.render(cells, data);
    for (let i = 0; i < 5; i++) {
      tick(entries, cells, inkInfo, 30, 6);
      updated.render(cells, data);
    }
    const fresh = createVoronoiRenderer(colors, 30, 30, 2, kernel);
    const freshData = new Uint8ClampedArray(data.length);
    fresh.render(cells, freshData);
    expect(data).toEqual(freshData);
  });

  it("reports whether anything changed", () => {
    const renderer = createVoronoiRenderer(["#ff0000", "#0000ff"], 10, 10, 2, kernel);
    const data = new Uint8ClampedArray(renderer.width * renderer.height * 4);
    const cells = new Int32Array(100);
    expect(renderer.render(cells, data)).toBe(true);
    expect(renderer.render(cells, data)).toBe(false);
    cells[0] = 1;
    expect(renderer.render(cells, data)).toBe(true);
  });
});
