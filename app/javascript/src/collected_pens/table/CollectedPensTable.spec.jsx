// @ts-check
import React from "react";
import { render, act, waitFor } from "@testing-library/react";
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
      daily_usage: 2,
      last_used_on: "2023-01-15",
      created_at: "2022-06-01",
      model_variant_id: 123
    },
    {
      brand: "Faber-Castell",
      model: "Ambition",
      nib: "EF",
      color: "red",
      comment: "",
      usage: null,
      daily_usage: null,
      last_used_on: null,
      created_at: "2022-07-15",
      model_variant_id: null
    },
    {
      brand: "Majohn",
      model: "Q1",
      nib: "fude",
      color: "gold",
      comment: null,
      usage: 5,
      daily_usage: 1,
      last_used_on: "2023-02-10",
      created_at: "2022-08-20",
      model_variant_id: 456
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

  it("global filter reduces visible rows", async () => {
    jest.useFakeTimers();
    const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
    try {
      const { getByLabelText, container } = render(
        <CollectedPensTable
          pens={pens}
          onLayoutChange={() => {
            return;
          }}
        />
      );

      await user.type(getByLabelText("Search"), "Majohn");
      await act(async () => {
        jest.runAllTimers();
      });

      await waitFor(() => {
        const rows = container.querySelectorAll("tbody tr");
        expect(rows.length).toBe(1);
      });

      expect(container).toHaveTextContent("Q1");
    } finally {
      jest.useRealTimers();
    }
  });

  it("footer counts update after filtering", async () => {
    jest.useFakeTimers();
    const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
    try {
      const { getByLabelText, getByText } = render(
        <CollectedPensTable
          pens={pens}
          onLayoutChange={() => {
            return;
          }}
        />
      );

      // Initially shows all counts
      expect(getByText("2 brands")).toBeInTheDocument();
      expect(getByText("3 pens")).toBeInTheDocument();

      // Filter to only Majohn
      await user.type(getByLabelText("Search"), "Majohn");
      await act(async () => {
        jest.runAllTimers();
      });

      await waitFor(() => {
        expect(getByText("1 brands")).toBeInTheDocument();
        expect(getByText("1 pens")).toBeInTheDocument();
      });
    } finally {
      jest.useRealTimers();
    }
  });

  it("null usage values sort correctly", async () => {
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

    // First click: sort descending (highest first)
    await user.click(headerCell);
    const rowsDesc = getAllByRole("row");
    expect(rowsDesc[1]).toHaveTextContent(/Q1/); // usage: 5

    // Second click: sort ascending (lowest first, nulls appear first in react-table v7)
    await user.click(headerCell);
    const rowsAsc = getAllByRole("row");
    expect(rowsAsc[1]).toHaveTextContent(/Ambition/); // usage: null (nulls sort first in ascending)
    expect(rowsAsc[2]).toHaveTextContent(/Loom/); // usage: 1
    expect(rowsAsc[3]).toHaveTextContent(/Q1/); // usage: 5
  });

  it("brand counting with varied data", () => {
    const pensWithDuplicateBrands = [
      ...pens,
      {
        brand: "Faber-Castell",
        model: "Essentio",
        nib: "M",
        color: "black",
        comment: "",
        usage: 0,
        daily_usage: 0,
        last_used_on: null,
        created_at: "2023-01-01",
        model_variant_id: null
      }
    ];

    const { getByText } = setup(
      <CollectedPensTable
        pens={pensWithDuplicateBrands}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Should still be 2 brands (Faber-Castell and Majohn)
    expect(getByText("2 brands")).toBeInTheDocument();
    expect(getByText("4 pens")).toBeInTheDocument();
  });

  it("comment column renders correctly", () => {
    const { container } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(container).toHaveTextContent("some comment");
  });

  it("sorting multiple times toggles direction correctly", async () => {
    const { getAllByRole, user } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const headerCell = getAllByRole("columnheader").find((e) => e.innerHTML.includes("Brand"));

    if (!headerCell) {
      throw new Error("Could not find Brand header cell");
    }

    // First click: ascending
    await user.click(headerCell);
    let rows = getAllByRole("row");
    expect(rows[1]).toHaveTextContent(/Faber-Castell/);

    // Second click: descending
    await user.click(headerCell);
    rows = getAllByRole("row");
    expect(rows[1]).toHaveTextContent(/Majohn/);

    // Third click: unsorted (back to original order)
    await user.click(headerCell);
    rows = getAllByRole("row");
    expect(rows[1]).toHaveTextContent(/Loom/);
  });

  it("model variant link renders when model_variant_id exists", () => {
    const { container } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const modelLinks = container.querySelectorAll('a[href*="/pen_variants/"]');
    expect(modelLinks.length).toBe(2);
    expect(modelLinks[0].getAttribute("href")).toBe("/pen_variants/123");
    expect(modelLinks[1].getAttribute("href")).toBe("/pen_variants/456");
  });

  it("model renders without link when model_variant_id is null", () => {
    const { container, getByText } = setup(
      <CollectedPensTable
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Check that Ambition (which has null model_variant_id) renders without link
    expect(getByText("Ambition")).toBeInTheDocument();

    // Count links - should only have 2 (for Loom and Q1)
    const modelLinks = container.querySelectorAll('a[href*="/pen_variants/"]');
    expect(modelLinks.length).toBe(2);
  });
});
