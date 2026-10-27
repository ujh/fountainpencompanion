import { render, screen, waitFor } from "@testing-library/react";
import * as fetchModule from "../../../fetch";
import { SignUps } from "../SignUps";

vi.mock("highcharts", () => ({ default: {} }));

// Mock HighchartsReact to just render a div with the options as data-prop
vi.mock("highcharts-react-official", () => ({
  default: ({ options }) => (
    <div data-testid="highcharts-mock">
      <span>{options?.title?.text}</span>
      <span>{options?.chart?.type}</span>
    </div>
  )
}));

// Mock Spinner
vi.mock("../../components/Spinner", () => ({
  Spinner: () => <div data-testid="spinner">Loading...</div>
}));

// Mock navigator.locks
beforeAll(() => {
  global.navigator.locks = {
    request: (_name, cb) => cb()
  };
});

afterAll(() => {
  delete global.navigator.locks;
});

describe("SignUps", () => {
  const mockData = [
    {
      name: "SignUps",
      data: [
        [1714608000000, 4],
        [1714694400000, 7]
      ]
    },
    {
      name: "Other",
      data: [
        [1714608000000, 1],
        [1714694400000, 2]
      ]
    }
  ];

  beforeEach(() => {
    vi.spyOn(fetchModule, "getRequest").mockImplementation(() =>
      Promise.resolve({
        json: () => Promise.resolve(mockData)
      })
    );
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("shows spinner while loading", async () => {
    render(<SignUps />);
    expect(screen.getByTestId("spinner")).toBeInTheDocument();
    // Wait for chart to appear
    await waitFor(() => screen.getByTestId("highcharts-mock"));
  });

  it("renders HighchartsReact with correct options after data loads", async () => {
    render(<SignUps />);
    const chart = await screen.findByTestId("highcharts-mock");
    expect(chart).toBeInTheDocument();
    expect(chart).toHaveTextContent("Signups per day");
    expect(chart).toHaveTextContent("spline");
    // Spinner should not be present after data loads
    expect(screen.queryByTestId("spinner")).not.toBeInTheDocument();
  });
});
