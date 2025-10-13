/* eslint-env jest */
/* global jest, describe, it, expect, beforeAll, afterAll, beforeEach, global */
import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import { Agents } from "../Agents";
import * as fetchModule from "../../../fetch";
import HighchartsReact from "highcharts-react-official";

// Mock Highcharts to prevent real code execution
jest.mock("highcharts", () => ({}));

// Mock Spinner to avoid unrelated markup
jest.mock("../../components/Spinner", () => ({
  Spinner: () => <div data-testid="spinner" />
}));

// Mock HighchartsReact to inspect props
jest.mock("highcharts-react-official", () => ({
  __esModule: true,
  default: jest.fn(() => <div data-testid="highcharts-chart" />)
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
    jest.clearAllMocks();
  });

  it("shows spinner while loading", () => {
    // Don't resolve fetch immediately
    jest.spyOn(fetchModule, "getRequest").mockReturnValue(new Promise(() => {}));
    render(<Agents />);
    expect(screen.getByTestId("spinner")).toBeInTheDocument();
  });

  it("fetches data and renders chart", async () => {
    const mockData = [
      { name: "Agent A", data: [1, 2, 3] },
      { name: "Agent B", data: [4, 5, 6] }
    ];
    jest.spyOn(fetchModule, "getRequest").mockResolvedValue({
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
