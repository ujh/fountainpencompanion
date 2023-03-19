import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CollectedPensTable } from "./CollectedPensTable";

describe("<CollectedPensTable />", () => {
  beforeEach(() => {
    const data = [
      {
        brand: "Faber-Castell",
        model: "Loom",
        nib: "B",
        color: "gunmetal",
        comment: "some comment",
        usage: 1,
        daily_usage: 2
      },
      {
        brand: "Faber-Castell",
        model: "Ambition",
        nib: "EF",
        color: "red",
        comment: "",
        usage: null,
        daily_usage: null
      },
      {
        brand: "Majohn",
        model: "Q1",
        nib: "fude",
        color: "gold",
        comment: null,
        usage: 5,
        daily_usage: 1
      }
    ];
    render(<CollectedPensTable pens={data} />);
  });

  it("renders the pens", () => {
    expect(screen.queryByText("Loom")).toBeDefined();
    expect(screen.queryByText("Ambition")).toBeDefined();
    expect(screen.queryByText("Q1")).toBeDefined();
  });

  it("renders the action buttons", () => {
    expect(screen.getAllByTitle("edit")).toHaveLength(3);
    expect(screen.getAllByTitle("archive")).toHaveLength(3);
  });

  it("renders the correct footers", () => {
    expect(screen.queryByText("2 brands")).toBeDefined();
    expect(screen.queryByText("3 pens")).toBeDefined();
  });

  it("sorts descending for the usage column", async () => {
    const user = userEvent.setup();
    const headerCell = screen
      .getAllByRole("columnheader")
      .find(
        (e) =>
          e.innerHTML.includes("Usage") && !e.innerHTML.includes("Daily Usage")
      );

    await user.click(headerCell);
    // Highest usage value
    expect(screen.getAllByRole("row")[1]).toHaveTextContent(/Q1/);
    await user.click(headerCell);
    // Lowest usage value
    expect(screen.getAllByRole("row")[1]).toHaveTextContent(/Ambition/);
  });

  it("sorts descending for the daily usage column", async () => {
    const user = userEvent.setup();
    const headerCell = screen
      .getAllByRole("columnheader")
      .find((e) => e.innerHTML.includes("Daily Usage"));

    await user.click(headerCell);
    // Highest usage value
    expect(screen.getAllByRole("row")[1]).toHaveTextContent(/Loom/);
    await user.click(headerCell);
    // Lowest usage value
    expect(screen.getAllByRole("row")[1]).toHaveTextContent(/Ambition/);
  });
});
