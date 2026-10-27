import { render, screen, waitFor } from "@testing-library/react";
import HighchartsReact from "highcharts-react-official";
import * as fetchModule from "../../../fetch";
import { Agents } from "../Agents";

// Mock Highcharts to prevent real code execution
vi.mock("highcharts", () => ({ default: {} }));

// Mock Spinner to avoid unrelated markup
vi.mock("../../components/Spinner", () => ({
  Spinner: () => <div data-testid="spinner" />
}));

// Mock HighchartsReact to inspect props
vi.mock("highcharts-react-official", () => ({
  default: vi.fn(() => <div data-testid="highcharts-chart" />)
}));

// Mock navigator.locks
beforeAll(() => {
  global.navigator.locks = {
    request: (name, cb) => cb()
  };
});

afterAll(() => {
  delete global.navigator.locks;
});

describe("Agents component", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("shows spinner while loading", () => {
    // Don't resolve fetch immediately
    vi.spyOn(fetchModule, "getRequest").mockReturnValue(new Promise(() => {}));
    render(<Agents />);
    expect(screen.getByTestId("spinner")).toBeInTheDocument();
  });

  it("fetches data and renders chart", async () => {
    const mockData = [
      { name: "Agent A", data: [1, 2, 3] },
      { name: "Agent B", data: [4, 5, 6] }
    ];
    vi.spyOn(fetchModule, "getRequest").mockResolvedValue({
      json: () => Promise.resolve(mockData)
    });

    render(<Agents />);
    // Spinner should show first
    expect(screen.getByTestId("spinner")).toBeInTheDocument();

    // Wait for chart to appear
    await waitFor(() => {
      expect(screen.getByTestId("highcharts-chart")).toBeInTheDocument();
    });

    // Check HighchartsReact was called with correct options
    expect(HighchartsReact).toHaveBeenCalledWith(
      expect.objectContaining({
        highcharts: expect.anything(),
        options: expect.objectContaining({
          chart: { type: "column" },
          series: mockData,
          title: { text: "Agent executions per day" }
        })
      }),
      undefined
    );
  });
});
