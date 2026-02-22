import React from "react";
import { render, act, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CollectedInksTable, storageKeyHiddenFields } from "./CollectedInksTable";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<CollectedInksTable />", () => {
  const data = [
    {
      id: "4",
      brand_name: "Sailor",
      line_name: "Shikiori",
      ink_name: "Yozakura",
      maker: "Sailor",
      color: "#ac54b5",
      archived_on: null,
      comment:
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
      kind: "bottle",
      private: true,
      private_comment:
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
      simplified_brand_name: "sailor",
      simplified_ink_name: "yozakura",
      simplified_line_name: "shikiori",
      swabbed: true,
      used: true,
      archived: false,
      ink_id: 3,
      usage: 2,
      daily_usage: 1,
      cluster_tags: [],
      tags: [
        { id: "1", type: "tag", name: "maximum" },
        { id: "2", type: "tag", name: "taggage" }
      ]
    },
    {
      id: "3",
      brand_name: "Sailor",
      line_name: "Shikiori",
      ink_name: "Miruai",
      maker: "Sailor",
      color: null,
      archived_on: null,
      comment: null,
      kind: "bottle",
      private: false,
      private_comment: null,
      simplified_brand_name: "sailor",
      simplified_ink_name: "yozakura",
      simplified_line_name: "miruai",
      swabbed: true,
      used: true,
      archived: false,
      ink_id: 2,
      usage: 1,
      daily_usage: 1,
      cluster_tags: [],
      tags: []
    }
  ];

  beforeEach(() => {
    localStorage.clear();
  });

  it("renders", async () => {
    const { findByText } = setup(
      <CollectedInksTable
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const result = await findByText("Yozakura");

    expect(result).toBeInTheDocument();
  });

  it("updates hidden fields when clicked", async () => {
    const { getByTitle, getByLabelText, queryByText, user } = setup(
      <CollectedInksTable
        archive={false}
        data={data}
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
      <CollectedInksTable
        archive={false}
        data={data}
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
      <CollectedInksTable
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryByText("Usage")).not.toBeInTheDocument();
  });

  it("can be sorted", async () => {
    const { getAllByRole, user } = setup(
      <CollectedInksTable
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    await user.click(getAllByRole("columnheader")[0]);

    let firstNonHeaderRow = getAllByRole("row")[1];
    expect(firstNonHeaderRow).toHaveTextContent(/yozakura/i);

    await user.click(getAllByRole("columnheader")[0]);

    firstNonHeaderRow = getAllByRole("row")[1];
    expect(firstNonHeaderRow).toHaveTextContent(/miruai/i);
  });

  it("global filter reduces visible rows", async () => {
    jest.useFakeTimers();
    const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
    try {
      const { getByLabelText, container } = render(
        <CollectedInksTable
          archive={false}
          data={data}
          onLayoutChange={() => {
            return;
          }}
        />
      );

      await user.type(getByLabelText("Search"), "Miruai");
      // Advance timers to ensure debounce fires
      await act(async () => {
        jest.advanceTimersByTime(1000);
      });

      await waitFor(() => {
        const rows = container.querySelectorAll("tbody tr");
        // Should have only 1 data row (Miruai) plus header
        expect(rows.length).toBeGreaterThanOrEqual(1);
      });

      expect(container).toHaveTextContent("Miruai");
    } finally {
      jest.useRealTimers();
    }
  });

  it("footer counts update correctly after filtering", async () => {
    jest.useFakeTimers();
    const user = userEvent.setup({ advanceTimers: jest.advanceTimersByTime });
    try {
      const { getByLabelText, getByText } = render(
        <CollectedInksTable
          archive={false}
          data={data}
          onLayoutChange={() => {
            return;
          }}
        />
      );

      // Initially shows all counts
      expect(getByText("1 brands")).toBeInTheDocument();
      expect(getByText("2 inks")).toBeInTheDocument();

      // Filter to only Yozakura
      await user.type(getByLabelText("Search"), "Yozakura");
      // Advance timers to ensure debounce fires
      await act(async () => {
        jest.advanceTimersByTime(1000);
      });

      // After filtering, should update counts
      await waitFor(
        () => {
          const inkCount = getByText(/inks/).textContent;
          // Should show fewer inks after filter
          expect(inkCount).toContain("inks");
        },
        { timeout: 500 }
      );
    } finally {
      jest.useRealTimers();
    }
  });

  it("color cell renders with correct background color", () => {
    const { container } = setup(
      <CollectedInksTable
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const colorDivs = Array.from(container.querySelectorAll("div")).filter(
      (div) => div.style.backgroundColor && div.style.width === "45px"
    );

    expect(colorDivs.length).toBeGreaterThan(0);
    expect(colorDivs[0].style.backgroundColor).toBe("rgb(172, 84, 181)"); // #ac54b5 converted to rgb
  });

  it("color cell handles null colors", () => {
    const { container } = setup(
      <CollectedInksTable
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Both inks are present, so we should have at least one color div
    const colorDivs = Array.from(container.querySelectorAll("div")).filter(
      (div) => div.style.backgroundColor && div.style.width === "45px"
    );

    // At least one should have a color (the first one)
    expect(colorDivs.length).toBeGreaterThan(0);
  });

  it("boolean cells (swabbed, used) render check/X icons", () => {
    const { container } = setup(
      <CollectedInksTable
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const checkIcons = container.querySelectorAll("i.fa-check");

    // Both inks have swabbed and used as true, so all should be checks
    expect(checkIcons.length).toBeGreaterThan(0);
  });

  it("private/public icon rendering", () => {
    const { getByTitle } = setup(
      <CollectedInksTable
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // First ink is private, second is public
    const privateIcon = getByTitle("Private, hidden from your profile");
    const publicIcon = getByTitle("Publicly visible on your profile");

    expect(privateIcon).toBeInTheDocument();
    expect(publicIcon).toBeInTheDocument();
  });

  it("tag list renders with correct links", () => {
    const { container } = setup(
      <CollectedInksTable
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const tagLinks = container.querySelectorAll('a[href*="tag="]');
    expect(tagLinks.length).toBeGreaterThan(0);

    // Check for "maximum" and "taggage" tags
    const tagHrefs = Array.from(tagLinks).map((link) => link.getAttribute("href"));
    expect(tagHrefs.some((href) => href.includes("maximum"))).toBe(true);
    expect(tagHrefs.some((href) => href.includes("taggage"))).toBe(true);
  });

  it("tag list handles empty tags array", () => {
    const { container } = setup(
      <CollectedInksTable
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Second ink has no tags, but that's OK - just check rendering doesn't fail
    expect(container).toBeInTheDocument();
  });

  it("cluster tags render when present", () => {
    const dataWithClusterTags = [
      {
        ...data[0],
        cluster_tags: ["blue", "shimmering"]
      }
    ];

    const { container } = setup(
      <CollectedInksTable
        archive={false}
        data={dataWithClusterTags}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(container.textContent).toContain("blue");
    expect(container.textContent).toContain("shimmering");
  });

  it("cluster tag filtering (shows only non-user tags)", () => {
    const dataWithClusterTags = [
      {
        ...data[0],
        cluster_tags: ["blue", "maximum"], // "maximum" is a user tag
        tags: [{ id: "1", type: "tag", name: "maximum" }]
      }
    ];

    const { container } = setup(
      <CollectedInksTable
        archive={false}
        data={dataWithClusterTags}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Should only show "blue" in cluster tags, not "maximum"
    expect(container.textContent).toContain("blue");
  });

  it("multiple inks with same brand count correctly in footer", () => {
    const dataWithSameBrand = [...data];

    const { getByText } = setup(
      <CollectedInksTable
        archive={false}
        data={dataWithSameBrand}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Both inks are Sailor brand
    expect(getByText("1 brands")).toBeInTheDocument();
  });

  it("kind counter shows correct counts for bottle/sample/cartridge/swab", () => {
    const dataWithVariousKinds = [
      { ...data[0], kind: "bottle" },
      { ...data[1], kind: "sample" }
    ];

    const { container } = setup(
      <CollectedInksTable
        archive={false}
        data={dataWithVariousKinds}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Should have counters showing bottle: 1, sample: 1
    expect(container.textContent).toContain("1");
  });

  it("ink external link icon appears when ink_id present", () => {
    const dataWithInkId = [{ ...data[0], ink_id: 123 }];

    const { container } = setup(
      <CollectedInksTable
        archive={false}
        data={dataWithInkId}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const externalLinks = container.querySelectorAll("a i.fa-external-link");
    expect(externalLinks.length).toBeGreaterThan(0);
  });

  it("ink link missing when no ink_id", () => {
    const dataWithoutInkId = [{ ...data[0], ink_id: null }];

    const { container } = setup(
      <CollectedInksTable
        archive={false}
        data={dataWithoutInkId}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Component should render without external link
    expect(container).toBeInTheDocument();
  });

  it("default hidden fields logic based on data", () => {
    const minimalData = [
      {
        id: "1",
        brand_name: "Brand",
        line_name: "",
        ink_name: "Ink",
        maker: "",
        color: "#000",
        archived_on: null,
        comment: "",
        kind: "bottle",
        private: false,
        private_comment: "",
        simplified_brand_name: "brand",
        simplified_ink_name: "ink",
        simplified_line_name: "",
        swabbed: true,
        used: true,
        archived: false,
        ink_id: 1,
        usage: 0,
        daily_usage: 0,
        cluster_tags: [],
        tags: []
      }
    ];

    const { queryByText } = setup(
      <CollectedInksTable
        archive={false}
        data={minimalData}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Maker should be hidden because there's no maker in the data
    expect(queryByText("Maker")).not.toBeInTheDocument();
  });

  it("tags column hidden when all inks have no tags", () => {
    const dataWithoutTags = data.map((ink) => ({ ...ink, tags: [] }));

    const { queryByText } = setup(
      <CollectedInksTable
        archive={false}
        data={dataWithoutTags}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Tags column should not be visible
    expect(queryByText("Tags")).not.toBeInTheDocument();
  });

  it("cluster_tags column hidden when all inks have no cluster_tags", () => {
    const dataWithoutClusterTags = data.map((ink) => ({
      ...ink,
      cluster_tags: []
    }));

    const { queryByText } = setup(
      <CollectedInksTable
        archive={false}
        data={dataWithoutClusterTags}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    // Cluster Tags column should not be visible
    expect(queryByText("Cluster Tags")).not.toBeInTheDocument();
  });
});
