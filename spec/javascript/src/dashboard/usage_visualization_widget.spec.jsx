import { render, screen } from "@testing-library/react";
import { buildGrid, UsageVisualizationWidget } from "dashboard/usage_visualization_widget";
import { rest } from "msw";
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
    rest.get("/dashboard/widgets/usage_visualization.json", (req, res, ctx) => {
      return res(
        ctx.json(
          widgetData(
            [
              { ink_name: "Pilot Blue", color: "#0000ff", count: 5 },
              { ink_name: "Diamine Red", color: "#ff0000", count: 3 }
            ],
            "usage_records",
            15
          )
        )
      );
    }),
    rest.get("/account", (req, res, ctx) => {
      return res(ctx.json(accountData));
    }),
    rest.put("/account", (req, res, ctx) => {
      return res(ctx.json({}));
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
      rest.get("/dashboard/widgets/usage_visualization.json", (req, res, ctx) => {
        return res(ctx.json(widgetData([], "insufficient", 0)));
      })
    );

    render(<UsageVisualizationWidget renderWhenInvisible />);
    await screen.findByText(/Not enough usage data yet/);
  });

  it("shows fallback message when using currently inked data", async () => {
    server.use(
      rest.get("/dashboard/widgets/usage_visualization.json", (req, res, ctx) => {
        return res(
          ctx.json(
            widgetData(
              [{ ink_name: "Pilot Blue", color: "#0000ff", count: 6 }],
              "currently_inked",
              5
            )
          )
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
