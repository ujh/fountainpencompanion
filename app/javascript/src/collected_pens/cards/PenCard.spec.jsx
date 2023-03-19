// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PenCard } from "./PenCard";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<PenCard />", () => {
  it("renders comments", () => {
    const { getByText } = setup(
      <PenCard
        id="1"
        brand="Pilot"
        model="Metropolitan"
        color="Black"
        nib="F"
        comment="This is a comment"
        hiddenFields={[]}
      />
    );

    expect(getByText("This is a comment")).toBeInTheDocument();
  });

  it("renders usage stats", () => {
    const { getByText } = setup(
      <PenCard
        id="1"
        brand="Pilot"
        model="Metropolitan"
        color="Black"
        nib="F"
        usage={1}
        daily_usage={10}
        hiddenFields={[]}
      />
    );

    expect(getByText("Usage")).toBeInTheDocument();
    expect(getByText("1 inked (10 daily usages)")).toBeInTheDocument();
  });

  it("doesn't render a usage header if there are no stats", () => {
    const { queryByText } = setup(
      <PenCard
        id="1"
        brand="Pilot"
        model="Metropolitan"
        color="Black"
        nib="F"
        comment="This is a comment"
        hiddenFields={[]}
      />
    );

    expect(queryByText("Usage")).not.toBeInTheDocument();
  });

  it("hides as expected if given hidden fields", () => {
    const { queryByText } = setup(
      <PenCard
        id="1"
        brand="Pilot"
        model="Metropolitan"
        color="Black"
        nib="CM"
        comment="This is a comment"
        usage={1}
        daily_usage={10}
        hiddenFields={[
          "brand",
          "model",
          "nib",
          "color",
          "comment",
          "usage",
          "daily_usage"
        ]}
      />
    );

    expect(queryByText("Pilot")).not.toBeInTheDocument();
    expect(queryByText("Metropolitan")).not.toBeInTheDocument();
    expect(queryByText("CM")).not.toBeInTheDocument();
    expect(queryByText("Black")).not.toBeInTheDocument();
    expect(queryByText("This is a comment")).not.toBeInTheDocument();
    expect(queryByText("Usage")).not.toBeInTheDocument();
  });
});
