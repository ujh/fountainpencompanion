import { act, render, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CurrentlyInkedTable, storageKeyHiddenFields } from "./CurrentlyInkedTable";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<CurrentlyInkedTable />", () => {
  const currentlyInked = [
    {
      id: 1,
      inked_on: "2023-01-15",
      archived_on: null,
      comment: "",
      last_used_on: "2023-02-04",
      pen_name: "Sailor Pro Gear, Black, M",
      ink_name: "Sailor Shikiori Yozakura",
      used_today: false,
      daily_usage: 1,
      refillable: true,
      unarchivable: false,
      archived: false,
      collected_ink: {
        color: "#ac54b5",
        brand_name: "Sailor",
        line_name: "Shikiori",
        ink_name: "Yozakura"
      },
      collected_pen: { model_variant_id: 123 }
    },
    {
      id: 2,
      inked_on: "2023-01-15",
      archived_on: null,
      comment: "",
      last_used_on: "2023-02-04",
      pen_name: "Platinum #3776 Century, Black Diamond, F",
      ink_name: "Platinum Carbon Black - cartridge",
      used_today: false,
      daily_usage: 1,
      refillable: true,
      unarchivable: false,
      archived: false,
      collected_ink: {
        color: "#000",
        brand_name: "Platinum",
        line_name: "",
        ink_name: "Carbon Black"
      },
      collected_pen: { model_variant_id: null }
    }
  ];

  beforeEach(() => {
    localStorage.clear();
  });

  it("renders", async () => {
    const { findByText } = setup(
      <CurrentlyInkedTable
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const result = await findByText("Sailor Shikiori Yozakura");

    expect(result).toBeInTheDocument();
  });

  it("updates hidden fields when clicked", async () => {
    const { getByTitle, getByLabelText, queryByText, user } = setup(
      <CurrentlyInkedTable
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryByText("Pen")).toBeInTheDocument();

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show pen"));

    expect(queryByText("Pen")).not.toBeInTheDocument();
  });

  it("resets hidden fields when restore defaults is clicked", async () => {
    const { getByText, getByTitle, getByLabelText, queryByText, user } = setup(
      <CurrentlyInkedTable
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show pen"));

    expect(queryByText("Pen")).not.toBeInTheDocument();

    await user.click(getByText("Restore defaults"));

    expect(queryByText("Pen")).toBeInTheDocument();
  });

  it("renders with hidden fields restored from localStorage", () => {
    localStorage.setItem(storageKeyHiddenFields, JSON.stringify(["pen_name"]));

    const { queryByText } = setup(
      <CurrentlyInkedTable
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryByText("Pen")).not.toBeInTheDocument();
  });

  it("renders RelativeDate cells correctly", () => {
    const { container } = setup(
      <CurrentlyInkedTable
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const relativeDates = container.querySelectorAll("span[title]");
    expect(relativeDates.length).toBeGreaterThan(0);
  });

  it("renders color swatch from collected_ink.color", () => {
    const { container } = setup(
      <CurrentlyInkedTable
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const colorDivs = Array.from(container.querySelectorAll("div")).filter(
      (div) => div.style.backgroundColor && div.style.width === "45px"
    );

    expect(colorDivs.length).toBe(2);
    expect(colorDivs[0].style.backgroundColor).toBeTruthy();
    expect(colorDivs[1].style.backgroundColor).toBeTruthy();
  });

  it("renders pen link when model_variant_id exists", () => {
    const { container } = setup(
      <CurrentlyInkedTable
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const penLinks = container.querySelectorAll('a[href*="/pen_variants/"]');
    expect(penLinks.length).toBe(1);
    expect(penLinks[0].getAttribute("href")).toBe("/pen_variants/123");
  });

  it("does not render pen link when model_variant_id is null", () => {
    const { container, getByText } = setup(
      <CurrentlyInkedTable
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(getByText("Platinum #3776 Century, Black Diamond, F")).toBeInTheDocument();
    const penLinks = container.querySelectorAll('a[href*="/pen_variants/"]');
    expect(penLinks.length).toBe(1);
  });

  it("renders footer with correct counts", () => {
    const { getByText } = setup(
      <CurrentlyInkedTable
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(getByText("2 pens")).toBeInTheDocument();
    expect(getByText("2 inks")).toBeInTheDocument();
  });

  it("sorting works with null values", async () => {
    const dataWithNulls = [
      ...currentlyInked,
      {
        id: 3,
        inked_on: "2023-01-10",
        archived_on: null,
        comment: "",
        last_used_on: null,
        pen_name: "Pilot Custom 823, Amber, M",
        ink_name: "Pilot Iroshizuku Amber",
        used_today: false,
        daily_usage: 0,
        refillable: true,
        unarchivable: false,
        archived: false,
        collected_ink: {
          color: "#c48a3f",
          brand_name: "Pilot",
          line_name: "Iroshizuku",
          ink_name: "Amber"
        },
        collected_pen: { model_variant_id: null }
      }
    ];

    const { getByText, container, user } = setup(
      <CurrentlyInkedTable
        currentlyInked={dataWithNulls}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    await user.click(getByText("Last Used"));

    const rows = container.querySelectorAll("tbody tr");
    expect(rows.length).toBe(3);
    expect(container).toHaveTextContent("Pilot Custom 823, Amber, M");
  });

  it("global filter reduces visible rows", async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    try {
      const { getByLabelText, container } = render(
        <CurrentlyInkedTable
          currentlyInked={currentlyInked}
          onLayoutChange={() => {
            return;
          }}
        />
      );

      await user.type(getByLabelText("Search"), "Platinum");
      await act(async () => {
        vi.runAllTimers();
      });

      await waitFor(() => {
        const rows = container.querySelectorAll("tbody tr");
        expect(rows.length).toBe(1);
      });

      expect(container).toHaveTextContent("Platinum #3776 Century, Black Diamond, F");
    } finally {
      vi.useRealTimers();
    }
  });

  it("filter persists during sort", async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    try {
      const { getByLabelText, getByText, container } = render(
        <CurrentlyInkedTable
          currentlyInked={currentlyInked}
          onLayoutChange={() => {
            return;
          }}
        />
      );

      await user.type(getByLabelText("Search"), "Platinum");
      await act(async () => {
        vi.runAllTimers();
      });

      await waitFor(() => {
        const rows = container.querySelectorAll("tbody tr");
        expect(rows.length).toBe(1);
      });

      await user.click(getByText("Pen"));

      await waitFor(() => {
        const rows = container.querySelectorAll("tbody tr");
        expect(rows.length).toBe(1);
      });

      expect(container).toHaveTextContent("Platinum #3776 Century, Black Diamond, F");
    } finally {
      vi.useRealTimers();
    }
  });

  describe("state in the URL", () => {
    const params = () => new URLSearchParams(window.location.search);
    const linkParams = (link) =>
      new URL(link.getAttribute("href"), window.location.origin).searchParams;

    it("carries the search and the sorting into its links", () => {
      window.history.replaceState(null, "", "/currently_inked?q=Sailor&sort=pen_name");
      const { getByRole, getAllByTitle } = setup(
        <CurrentlyInkedTable currentlyInked={currentlyInked} onLayoutChange={() => {}} />
      );

      const links = [
        getByRole("link", { name: /Add.entry/ }),
        getAllByTitle("Refill this pen")[0],
        getAllByTitle("edit")[0],
        getAllByTitle("archive")[0]
      ];
      links.forEach((link) => {
        expect(linkParams(link).get("q")).toEqual("Sailor");
        expect(linkParams(link).get("sort")).toEqual("pen_name");
      });
    });

    it("restores the sorting from the URL", () => {
      window.history.replaceState(null, "", "/currently_inked?sort=pen_name");
      const { getAllByRole } = setup(
        <CurrentlyInkedTable currentlyInked={currentlyInked} onLayoutChange={() => {}} />
      );

      const rows = getAllByRole("row");
      expect(rows[1]).toHaveTextContent(/Platinum/);
      expect(rows[2]).toHaveTextContent(/Sailor/);
    });

    it("restores the search from the URL", () => {
      window.history.replaceState(null, "", "/currently_inked?q=Platinum");
      const { getByLabelText, container } = setup(
        <CurrentlyInkedTable currentlyInked={currentlyInked} onLayoutChange={() => {}} />
      );

      expect(getByLabelText("Search")).toHaveValue("Platinum");
      const rows = container.querySelectorAll("tbody tr");
      expect(rows).toHaveLength(1);
      expect(rows[0]).toHaveTextContent(/Platinum/);
    });

    it("writes sorting by a nested column and search to the URL", async () => {
      const { getByText, getByLabelText, user } = setup(
        <CurrentlyInkedTable currentlyInked={currentlyInked} onLayoutChange={() => {}} />
      );

      await user.click(getByText("Color"));
      expect(params().get("sort")).toEqual("collected_ink_color");

      await user.type(getByLabelText("Search"), "Sailor");
      await waitFor(() => expect(params().get("q")).toEqual("Sailor"));
    });
  });
});
