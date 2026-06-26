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

  describe("URL filter sync", () => {
    afterEach(() => {
      window.history.replaceState(null, "", "/users/1");
    });

    it("initializes filters from known query params and ignores unknown ones", () => {
      window.history.replaceState(null, "", "/users/1?kind=sample&utm_source=foo");
      const instance = new Table({});
      expect(instance.state.filtered).toEqual([{ id: "kind", value: "sample" }]);
    });

    it("starts with no filters when no query params are present", () => {
      window.history.replaceState(null, "", "/users/1");
      const instance = new Table({});
      expect(instance.state.filtered).toEqual([]);
    });

    it("writes active filters to the URL and drops 'all' and empty values", () => {
      window.history.replaceState(null, "", "/users/1?utm_source=foo");
      const instance = new Table({});
      instance.setState = jest.fn();
      instance.onFilteredChange([
        { id: "kind", value: "bottle" },
        { id: "comparison", value: "all" },
        { id: "brand_name", value: "" }
      ]);
      const params = new URLSearchParams(window.location.search);
      expect(params.get("kind")).toEqual("bottle");
      expect(params.has("comparison")).toBe(false);
      expect(params.has("brand_name")).toBe(false);
      // preserves unrelated query params
      expect(params.get("utm_source")).toEqual("foo");
    });

    it("clears a filter param when its value is reset", () => {
      window.history.replaceState(null, "", "/users/1?kind=sample");
      const instance = new Table({});
      instance.setState = jest.fn();
      instance.onFilteredChange([]);
      expect(window.location.search).toEqual("");
    });
  });
});
