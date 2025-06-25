/* eslint-env jest */
/* eslint-env jest */
/* global jest, describe, it, expect, beforeAll, afterAll, beforeEach, afterEach, global */
import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import { BotSignUps } from "../BotSignUps";
import * as fetchModule from "../../../fetch";

// Mock Highcharts to prevent real code execution
jest.mock("highcharts", () => ({}));

// Mock HighchartsReact to just render a placeholder
jest.mock("highcharts-react-official", () => ({
  __esModule: true,
  default: ({ options }) => (
    <div data-testid="highcharts-mock">
      <span>{options?.title?.text}</span>
      <span>{options?.chart?.type}</span>
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

describe("BotSignUps", () => {
  const mockData = [
    {
      name: "Bot1",
      data: [
        [1714608000000, 2],
        [1714694400000, 3]
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
    jest.clearAllMocks();
  });

  it("shows spinner while loading", async () => {
    render(<BotSignUps />);
    expect(screen.getByTestId("spinner")).toBeInTheDocument();
    // Wait for chart to appear
    await waitFor(() => screen.getByTestId("highcharts-mock"));
  });

  it("fetches data and renders HighchartsReact with correct options", async () => {
    render(<BotSignUps />);
    const chart = await screen.findByTestId("highcharts-mock");
    expect(chart).toBeInTheDocument();
    expect(chart).toHaveTextContent("Bot signups per day");
    expect(chart).toHaveTextContent("spline");
    // Spinner should not be present after data loads
    expect(screen.queryByTestId("spinner")).not.toBeInTheDocument();
  });
});
