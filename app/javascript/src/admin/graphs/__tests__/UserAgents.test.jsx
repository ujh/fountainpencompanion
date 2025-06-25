/* eslint-env jest */
/* global jest, describe, it, expect, beforeAll, afterAll, beforeEach, afterEach, global */
import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import { UserAgents } from "../UserAgents";
import * as fetchModule from "../../../fetch";

jest.mock("highcharts", () => ({}));

// Mock HighchartsReact to just render a div with the options as JSON
jest.mock("highcharts-react-official", () => ({
  __esModule: true,
  default: ({ options }) => (
    <div data-testid="highcharts-mock">
      <span>{options?.title?.text}</span>
      <span>{options?.chart?.type}</span>
      <span>{JSON.stringify(options?.series)}</span>
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

describe("UserAgents", () => {
  const mockData = [
    {
      name: "Chrome",
      data: [
        [1714608000000, 12],
        [1714694400000, 15]
      ]
    },
    {
      name: "Firefox",
      data: [
        [1714608000000, 5],
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
    render(<UserAgents />);
    expect(screen.getByTestId("spinner")).toBeInTheDocument();
    // Wait for chart to appear
    await waitFor(() => screen.getByTestId("highcharts-mock"));
  });

  it("renders HighchartsReact with correct options after data loads", async () => {
    render(<UserAgents />);
    const chart = await screen.findByTestId("highcharts-mock");
    expect(chart).toBeInTheDocument();
    expect(chart).toHaveTextContent("User Agents");
    expect(chart).toHaveTextContent("spline");
    expect(chart).toHaveTextContent("Chrome");
    expect(chart).toHaveTextContent("Firefox");
    // Spinner should not be present after data loads
    expect(screen.queryByTestId("spinner")).not.toBeInTheDocument();
  });
});
