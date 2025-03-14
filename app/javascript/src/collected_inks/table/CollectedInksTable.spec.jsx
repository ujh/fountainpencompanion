import React from "react";
import { render } from "@testing-library/react";
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
});
