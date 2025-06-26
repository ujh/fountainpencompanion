import React from "react";
import { render, screen } from "@testing-library/react";
import { EntriesList } from "./EntriesList";

// Mock the SearchLink component since it's tested separately
jest.mock("./SearchLink", () => ({
  SearchLink: ({ e, fields }) => (
    <div data-testid="search-link" data-entry-id={e.id} data-fields={fields.join(",")}>
      Search Link
    </div>
  )
}));

describe("EntriesList", () => {
  const mockEntries = [
    { id: 1, brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" },
    { id: 2, brand: "Pilot", line: "Iroshizuku", name: "Yama-budo" },
    { id: 3, brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" }, // Duplicate
    { id: 4, brand: "Diamine", line: "Standard", name: "Oxblood" }
  ];

  const defaultFields = ["brand", "line", "name"];

  it("renders table rows for unique entries", () => {
    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={mockEntries} fields={defaultFields} />
        </tbody>
      </table>
    );

    const rows = container.querySelectorAll("tr");
    expect(rows).toHaveLength(3); // Should group duplicate Tsuki-yo entries
  });

  it("groups entries with identical field combinations", () => {
    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={mockEntries} fields={defaultFields} />
        </tbody>
      </table>
    );

    // Should have a row with count of 2 for the duplicate Tsuki-yo entries
    const countCells = container.querySelectorAll("td:first-child");
    const counts = Array.from(countCells).map((cell) => parseInt(cell.textContent));
    expect(counts).toContain(2);
    expect(counts).toContain(1);
  });

  it("sorts groups by count in descending order", () => {
    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={mockEntries} fields={defaultFields} />
        </tbody>
      </table>
    );

    const countCells = container.querySelectorAll("td:first-child");
    const counts = Array.from(countCells).map((cell) => parseInt(cell.textContent));

    // Should be sorted descending: [2, 1, 1] or similar
    for (let i = 0; i < counts.length - 1; i++) {
      expect(counts[i]).toBeGreaterThanOrEqual(counts[i + 1]);
    }
  });

  it("renders correct number of cells per row", () => {
    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={mockEntries} fields={defaultFields} />
        </tbody>
      </table>
    );

    const firstRow = container.querySelector("tr");
    const cells = firstRow.querySelectorAll("td");

    // Should have: count + fields + extraColumn + SearchLink + 2 empty = 8 cells
    expect(cells).toHaveLength(8);
  });

  it("displays field values in correct order", () => {
    const singleEntry = [{ id: 1, brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" }];

    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={singleEntry} fields={["brand", "line", "name"]} />
        </tbody>
      </table>
    );

    const cells = container.querySelectorAll("td");
    expect(cells[0].textContent).toBe("1"); // count
    expect(cells[1].textContent).toBe("Pilot"); // brand
    expect(cells[2].textContent).toBe("Iroshizuku"); // line
    expect(cells[3].textContent).toBe("Tsuki-yo"); // name
  });

  it("handles extraColumn function correctly", () => {
    const extraColumnFn = jest.fn((entry) => `Extra: ${entry.brand}`);
    const singleEntry = [{ id: 1, brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" }];

    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={singleEntry} fields={["brand"]} extraColumn={extraColumnFn} />
        </tbody>
      </table>
    );

    expect(extraColumnFn).toHaveBeenCalledWith(singleEntry[0]);
    expect(container.textContent).toContain("Extra: Pilot");
  });

  it("renders empty extraColumn cell when no extraColumn provided", () => {
    const singleEntry = [{ id: 1, brand: "Pilot" }];

    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={singleEntry} fields={["brand"]} />
        </tbody>
      </table>
    );

    const cells = container.querySelectorAll("td");
    const extraColumnCell = cells[2]; // count + brand + extraColumn
    expect(extraColumnCell.textContent).toBe("");
  });

  it("includes SearchLink component with correct props", () => {
    const singleEntry = [{ id: 1, brand: "Pilot", name: "Tsuki-yo" }];
    const fields = ["brand", "name"];

    render(
      <table>
        <tbody>
          <EntriesList entries={singleEntry} fields={fields} />
        </tbody>
      </table>
    );

    const searchLink = screen.getByTestId("search-link");
    expect(searchLink).toHaveAttribute("data-entry-id", "1");
    expect(searchLink).toHaveAttribute("data-fields", "brand,name");
  });

  it("handles empty entries array", () => {
    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={[]} fields={["brand"]} />
        </tbody>
      </table>
    );

    const rows = container.querySelectorAll("tr");
    expect(rows).toHaveLength(0);
  });

  it("handles empty fields array", () => {
    const singleEntry = [{ id: 1, brand: "Pilot" }];

    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={singleEntry} fields={[]} />
        </tbody>
      </table>
    );

    const cells = container.querySelectorAll("td");
    expect(cells[0].textContent).toBe("1"); // count
    // No field cells should be rendered
    expect(cells[1].textContent).toBe(""); // extraColumn cell
  });

  it("renders table rows with correct structure", () => {
    const singleEntry = [{ id: 42, brand: "Pilot" }];

    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={singleEntry} fields={["brand"]} />
        </tbody>
      </table>
    );

    const row = container.querySelector("tr");
    expect(row).toBeInTheDocument();
  });

  it("handles missing field values gracefully", () => {
    const entriesWithMissing = [
      { id: 1, brand: "Pilot" }, // missing line and name
      { id: 2, brand: "Pilot", line: "Iroshizuku" } // missing name
    ];

    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={entriesWithMissing} fields={["brand", "line", "name"]} />
        </tbody>
      </table>
    );

    const rows = container.querySelectorAll("tr");
    expect(rows).toHaveLength(2); // Should not group since undefined values differ
  });

  it("groups entries with same undefined field values", () => {
    const entriesWithSameUndefined = [
      { id: 1, brand: "Pilot" }, // line and name undefined
      { id: 2, brand: "Pilot" } // line and name undefined
    ];

    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={entriesWithSameUndefined} fields={["brand", "line", "name"]} />
        </tbody>
      </table>
    );

    const rows = container.querySelectorAll("tr");
    expect(rows).toHaveLength(1); // Should group since all field values are the same

    const countCell = container.querySelector("td:first-child");
    expect(countCell.textContent).toBe("2");
  });

  it("handles single field grouping", () => {
    const entries = [
      { id: 1, brand: "Pilot" },
      { id: 2, brand: "Pilot" },
      { id: 3, brand: "Diamine" }
    ];

    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={entries} fields={["brand"]} />
        </tbody>
      </table>
    );

    const rows = container.querySelectorAll("tr");
    expect(rows).toHaveLength(2); // Pilot (count: 2) and Diamine (count: 1)

    const countCells = container.querySelectorAll("td:first-child");
    const counts = Array.from(countCells).map((cell) => parseInt(cell.textContent));
    expect(counts).toEqual([2, 1]); // Should be sorted descending
  });

  it("renders two empty cells at the end of each row", () => {
    const singleEntry = [{ id: 1, brand: "Pilot" }];

    const { container } = render(
      <table>
        <tbody>
          <EntriesList entries={singleEntry} fields={["brand"]} />
        </tbody>
      </table>
    );

    const cells = container.querySelectorAll("td");
    const lastTwoCells = Array.from(cells).slice(-2);

    lastTwoCells.forEach((cell) => {
      expect(cell.textContent).toBe("");
    });
  });
});
