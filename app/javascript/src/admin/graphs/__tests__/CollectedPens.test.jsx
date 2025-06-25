/* eslint-env jest */
/* global jest, describe, it, expect, beforeAll, afterAll, global */
import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import { CollectedPens } from "../CollectedPens";
import * as fetchModule from "../../../fetch";

jest.mock("highcharts", () => ({}));

// Mock HighchartsReact to just render its props for inspection
jest.mock("highcharts-react-official", () => ({
  __esModule: true,
  default: ({ options }) => (
    <div data-testid="highcharts-mock">
      <span>Highcharts chart</span>
      <span data-testid="chart-type">{options.chart.type}</span>
      <span data-testid="chart-title">{options.title.text}</span>
      <span data-testid="series-name">{options.series[0].name}</span>
      <span data-testid="series-data">{JSON.stringify(options.series[0].data)}</span>
    </div>
  )
}));

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

describe("CollectedPens", () => {
  it("shows spinner while loading", () => {
    // Don't resolve fetch immediately
    jest.spyOn(fetchModule, "getRequest").mockReturnValue(new Promise(() => {}));
    render(<CollectedPens />);
    expect(screen.getByTestId("spinner")).toBeInTheDocument();
  });

  it("fetches data and renders chart", async () => {
    const mockData = [
      [1714608000000, 10],
      [1714694400000, 12]
    ];
    jest.spyOn(fetchModule, "getRequest").mockResolvedValue({
      json: () => Promise.resolve(mockData)
    });

    render(<CollectedPens />);
    // Wait for chart to appear
    await waitFor(() => expect(screen.getByTestId("highcharts-mock")).toBeInTheDocument());

    expect(screen.getByTestId("chart-type").textContent).toBe("spline");
    expect(screen.getByTestId("chart-title").textContent).toMatch(/Collected pens per day/);
    expect(screen.getByTestId("series-name").textContent).toBe("Collected Pens");
    expect(screen.getByTestId("series-data").textContent).toBe(JSON.stringify(mockData));
  });
});
