import { render, screen, waitFor } from "@testing-library/react";
import * as fetchModule from "../../../fetch";
import { Spam } from "../Spam";

vi.mock("highcharts", () => ({ default: {} }));

// Mock HighchartsReact to just render a div with the options as JSON for inspection
vi.mock("highcharts-react-official", () => {
  const MockHighchartsReact = (props) => (
    <div data-testid="highcharts-mock">{JSON.stringify(props.options)}</div>
  );
  MockHighchartsReact.displayName = "MockHighchartsReact";
  return {
    default: MockHighchartsReact
  };
});

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

describe("Spam", () => {
  const mockData = [
    {
      name: "Spam Accounts",
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
    // Delay the promise to simulate loading
    vi.spyOn(fetchModule, "getRequest").mockImplementation(
      () =>
        new Promise((resolve) => {
          setTimeout(
            () =>
              resolve({
                json: () => Promise.resolve(mockData)
              }),
            50
          );
        })
    );

    render(<Spam />);
    expect(screen.getByTestId("spinner")).toBeInTheDocument();
    // Wait for spinner to disappear
    await waitFor(() => expect(screen.queryByTestId("spinner")).not.toBeInTheDocument());
  });

  it("fetches data and renders HighchartsReact with correct options", async () => {
    render(<Spam />);
    // Wait for chart to appear
    const chart = await screen.findByTestId("highcharts-mock");
    expect(chart).toBeInTheDocument();

    // Parse the options passed to HighchartsReact
    const options = JSON.parse(chart.textContent);
    expect(options.chart.type).toBe("spline");
    expect(options.series).toEqual(mockData);
    expect(options.title.text).toMatch(/Spam accounts/i);
    expect(options.xAxis.type).toBe("datetime");
    expect(options.legend.enabled).toBe(true);
  });
});
