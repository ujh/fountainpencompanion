// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CollectedPensTable, storageKeyHiddenFields } from "./CollectedPensTable";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<CollectedPensTable />", () => {
  const pens = [
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

  beforeEach(() => {
    localStorage.clear();
  });

  it("renders the pens", () => {
    const { queryByText } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );
    expect(queryByText("Loom")).toBeDefined();
    expect(queryByText("Ambition")).toBeDefined();
    expect(queryByText("Q1")).toBeDefined();
  });

  it("renders the action buttons", () => {
    const { getAllByTitle } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );
    expect(getAllByTitle("edit")).toHaveLength(3);
    expect(getAllByTitle("archive")).toHaveLength(3);
  });

  it("renders the correct footers", () => {
    const { queryByText } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );
    expect(queryByText("2 brands")).toBeDefined();
    expect(queryByText("3 pens")).toBeDefined();
  });

  it("sorts descending for the usage column", async () => {
    const { getAllByRole, user } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );
    const headerCell = getAllByRole("columnheader").find(
      (e) => e.innerHTML.includes("Usage") && !e.innerHTML.includes("Daily Usage")
    );

    if (!headerCell) {
      throw new Error("Could not find header cell");
    }

    await user.click(headerCell);
    // Highest usage value
    expect(getAllByRole("row")[1]).toHaveTextContent(/Q1/);
    await user.click(headerCell);
    // Lowest usage value
    expect(getAllByRole("row")[1]).toHaveTextContent(/Ambition/);
  });

  it("sorts descending for the daily usage column", async () => {
    const { getAllByRole, user } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );
    const headerCell = getAllByRole("columnheader").find((e) =>
      e.innerHTML.includes("Daily Usage")
    );

    if (!headerCell) {
      throw new Error("Could not find header cell");
    }

    await user.click(headerCell);
    // Highest usage value
    expect(getAllByRole("row")[1]).toHaveTextContent(/Loom/);
    await user.click(headerCell);
    // Lowest usage value
    expect(getAllByRole("row")[1]).toHaveTextContent(/Ambition/);
  });

  it("updates hidden fields when clicked", async () => {
    const { getByTitle, getByLabelText, queryByText, user } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryByText("Usage")).toBeInTheDocument();

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show usage"));

    expect(queryByText("Usage")).not.toBeInTheDocument();
  });

  it("resets hidden fields when restore defaults is clicked", async () => {
    const { getByText, getByTitle, getByLabelText, queryByText, user } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show usage"));

    expect(queryByText("Usage")).not.toBeInTheDocument();

    await user.click(getByText("Restore defaults"));

    expect(queryByText("Usage")).toBeInTheDocument();
  });

  it("renders with hidden fields restored from localStorage", () => {
    localStorage.setItem(storageKeyHiddenFields, JSON.stringify(["usage"]));

    const { queryByText } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryByText("Usage")).not.toBeInTheDocument();
  });
});
