import React from "react";
import { render, screen, within } from "@testing-library/react";
import App from "../app";
import Table from "../table";

// Mock fetch and dependencies
jest.mock("../../fetch", () => ({
  getRequest: jest.fn(() =>
    Promise.resolve({
      ok: true,
      json: () =>
        Promise.resolve({
          data: { id: "1", attributes: { name: "Test User" } },
          included: [
            {
              type: "collected_inks",
              attributes: {
                ink_id: 101,
                brand_name: "BrandA",
                ink_name: "InkA",
                line_name: "LineA",
                maker: "MakerA",
                kind: "bottle",
                color: "#123456",
                comment: "Nice ink"
              }
            }
          ]
        })
    })
  )
}));

describe("App component", () => {
  it("renders without crashing and passes data to Table", async () => {
    render(<App />);
    // Wait for Table to appear (brand name should be rendered)
    expect(await screen.findByText("BrandA")).toBeInTheDocument();
    expect(screen.getByText("InkA")).toBeInTheDocument();
    expect(screen.getByText("LineA")).toBeInTheDocument();
  });

  it("calculates comparison correctly", () => {
    const instance = new App();
    const userInks = new Set([1, 2]);
    const loggedInUserInks = new Set([2, 3]);
    expect(instance.calculateComparison(1, userInks, loggedInUserInks)).toEqual({
      owned_by_user: true,
      owned_by_logged_in_user: false
    });
    expect(instance.calculateComparison(2, userInks, loggedInUserInks)).toEqual({
      owned_by_user: true,
      owned_by_logged_in_user: true
    });
    expect(instance.calculateComparison(3, userInks, loggedInUserInks)).toEqual({
      owned_by_user: false,
      owned_by_logged_in_user: true
    });
  });
});

describe("Table component", () => {
  const data = [
    {
      ink_id: 1,
      brand_name: "BrandA",
      ink_name: "InkA",
      line_name: "LineA",
      maker: "MakerA",
      kind: "bottle",
      color: "#123456",
      comment: "Nice ink",
      owned_by_user: true,
      owned_by_logged_in_user: false
    }
  ];

  it("renders table columns and data for the user", async () => {
    render(<Table data={data} additionalData={true} name="Test User" />);
    const table = await screen.findByRole("grid");
    expect(within(table).getByText("BrandA")).toBeInTheDocument();
    expect(within(table).getByText("InkA")).toBeInTheDocument();
    expect(within(table).getByText("Brand")).toBeInTheDocument();
    expect(within(table).getByText("Ink")).toBeInTheDocument();
  });
});
