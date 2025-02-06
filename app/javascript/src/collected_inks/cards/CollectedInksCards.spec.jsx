import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CollectedInksCards, storageKeyHiddenFields } from "./CollectedInksCards";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<CollectedInksCards />", () => {
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
      private: false,
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
      tags: [
        { id: "1", type: "tag", name: "maximum" },
        { id: "2", type: "tag", name: "taggage" }
      ]
    }
  ];

  beforeEach(() => {
    localStorage.clear();
  });

  it("renders", async () => {
    const { findByText } = setup(
      <CollectedInksCards
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const result = await findByText("Sailor Shikiori Yozakura");

    expect(result).toBeInTheDocument();
  });

  it("updates hidden fields when clicked", async () => {
    const { getByTitle, getByLabelText, queryByTestId, user } = setup(
      <CollectedInksCards
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryByTestId("usage")).toBeInTheDocument();

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show usage"));
    await user.click(getByLabelText("Show daily usage"));

    expect(queryByTestId("usage")).not.toBeInTheDocument();
  });

  it("resets hidden fields when restore defaults is clicked", async () => {
    const { getByText, getByTitle, getByLabelText, queryByText, getByTestId, user } = setup(
      <CollectedInksCards
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show usage"));
    await user.click(getByLabelText("Show daily usage"));

    expect(queryByText("2 inked (1 daily usages)")).not.toBeInTheDocument();

    await user.click(getByText("Restore defaults"));

    expect(getByTestId("usage")).toBeInTheDocument();
  });

  it("renders with hidden fields restored from localStorage", () => {
    localStorage.setItem(storageKeyHiddenFields, JSON.stringify(["usage", "daily_usage"]));

    const { queryByText } = setup(
      <CollectedInksCards
        archive={false}
        data={data}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryByText("2 inked (1 daily usages)")).not.toBeInTheDocument();
  });
});
