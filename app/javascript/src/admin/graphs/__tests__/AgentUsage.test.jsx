/* eslint-env jest */
/* global jest, describe, it, expect, beforeAll, afterAll, beforeEach, afterEach, global */
import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import { AgentUsage } from "../AgentUsage";
import * as fetchModule from "../../../fetch";

// Mock Highcharts to avoid running real code
jest.mock("highcharts", () => ({}));

// Mock HighchartsReact to just render a div with the options as data-prop
jest.mock("highcharts-react-official", () => {
  const MockHighchartsReact = ({ options }) => (
    <div data-testid="highcharts-mock">{JSON.stringify(options)}</div>
  );
  MockHighchartsReact.displayName = "MockHighchartsReact";
  return {
    __esModule: true,
    default: MockHighchartsReact
  };
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

describe("AgentUsage", () => {
  const mockData = [
    {
      name: "Agent1",
      data: [
        [1714608000000, 5],
        [1714694400000, 10]
      ]
    },
    {
      name: "Agent2",
      data: [
        [1714608000000, 2],
        [1714694400000, 7]
      ]
    }
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
    render(<AgentUsage />);
    expect(screen.getByTestId("spinner")).toBeInTheDocument();
    // Wait for chart to appear
    await waitFor(() => screen.getByTestId("highcharts-mock"));
  });

  it("renders HighchartsReact with correct options after data loads", async () => {
    render(<AgentUsage />);
    const chart = await screen.findByTestId("highcharts-mock");
    expect(chart).toBeInTheDocument();
    const options = JSON.parse(chart.textContent);
    expect(options.series).toEqual(mockData);
    expect(options.title.text).toMatch(/Agent tokens per day/);
    expect(options.chart.type).toBe("column");
  });
});
