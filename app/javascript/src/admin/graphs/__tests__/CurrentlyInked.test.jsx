/* eslint-env jest */
/* global jest, describe, it, expect, beforeAll, afterAll, beforeEach, afterEach, global */
import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import { CurrentlyInked } from "../CurrentlyInked";
import * as fetchModule from "../../../fetch";

jest.mock("highcharts", () => ({}));

// Mock HighchartsReact to just render a div with its props for inspection
jest.mock("highcharts-react-official", () => {
  const MockHighchartsReact = (props) => (
    <div data-testid="highcharts-mock">{JSON.stringify(props.options)}</div>
  );
  MockHighchartsReact.displayName = "MockHighchartsReact";
  return MockHighchartsReact;
});

// Mock Spinner
jest.mock("../../components/Spinner", () => ({
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

describe("CurrentlyInked", () => {
  const mockData = [
    [1717200000000, 8],
    [1717286400000, 12]
  ];

  beforeEach(() => {
    jest.spyOn(fetchModule, "getRequest").mockImplementation(() =>
      Promise.resolve({
        json: () => Promise.resolve(mockData)
      })
    );
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("shows spinner while loading", async () => {
    // Delay the promise to simulate loading
    jest.spyOn(fetchModule, "getRequest").mockImplementation(
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

    render(<CurrentlyInked />);
    expect(screen.getByTestId("spinner")).toBeInTheDocument();
    // Wait for spinner to disappear
    await waitFor(() => expect(screen.queryByTestId("spinner")).not.toBeInTheDocument());
  });

  it("fetches data and renders HighchartsReact with correct options", async () => {
    render(<CurrentlyInked />);
    // Wait for chart to appear
    const chart = await screen.findByTestId("highcharts-mock");
    expect(chart).toBeInTheDocument();

    // Parse the options passed to HighchartsReact
    const options = JSON.parse(chart.textContent);
    expect(options.chart.type).toBe("spline");
    expect(options.series[0].data).toEqual(mockData);
    expect(options.series[0].name).toBe("Currently Inked");
    expect(options.title.text).toMatch(/Currently inked per day/i);
    expect(options.xAxis.type).toBe("datetime");
  });

  it("renders legend as disabled", async () => {
    render(<CurrentlyInked />);
    const chart = await screen.findByTestId("highcharts-mock");
    const options = JSON.parse(chart.textContent);
    expect(options.legend.enabled).toBe(false);
  });
});
