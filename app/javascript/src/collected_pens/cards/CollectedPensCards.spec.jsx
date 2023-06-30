// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import {
  CollectedPensCards,
  storageKeyHiddenFields
} from "./CollectedPensCards";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<CollectedPensCards />", () => {
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

  it("renders", async () => {
    const { findByText } = setup(
      <CollectedPensCards
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const result = await findByText("Faber-Castell Loom");

    expect(result).toBeInTheDocument();
  });

  it("updates hidden fields when clicked", async () => {
    const { getByTitle, getByLabelText, queryAllByTestId, user } = setup(
      <CollectedPensCards
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryAllByTestId("usage")).not.toEqual([]);

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show usage"));
    await user.click(getByLabelText("Show daily usage"));
    await user.click(getByLabelText("Show last usage"));

    expect(queryAllByTestId("usage")).toEqual([]);
  });

  it("resets hidden fields when restore defaults is clicked", async () => {
    const { getByText, getByTitle, getByLabelText, queryAllByTestId, user } =
      setup(
        <CollectedPensCards
          pens={pens}
          onLayoutChange={() => {
            return;
          }}
        />
      );

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show usage"));
    await user.click(getByLabelText("Show daily usage"));
    await user.click(getByLabelText("Show last usage"));

    expect(queryAllByTestId("usage")).toEqual([]);

    await user.click(getByText("Restore defaults"));

    expect(queryAllByTestId("usage")).not.toEqual([]);
  });

  it("renders with hidden fields restored from localStorage", () => {
    localStorage.setItem(
      storageKeyHiddenFields,
      JSON.stringify(["usage", "daily_usage"])
    );

    const { queryByText } = setup(
      <CollectedPensCards
        pens={pens}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryByText("1 inked (2 daily usages)")).not.toBeInTheDocument();
  });
});
