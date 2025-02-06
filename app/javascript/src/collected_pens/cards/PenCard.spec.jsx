// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PenCard } from "./PenCard";
import { formatISO9075 } from "date-fns";

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
    const { getByText, getByTestId } = setup(
      <PenCard
        id="1"
        brand="Pilot"
        model="Metropolitan"
        color="Black"
        nib="F"
        usage={1}
        daily_usage={10}
        last_used_on={formatISO9075(new Date(), { representation: "date" })}
        hiddenFields={[]}
      />
    );

    expect(getByText("Usage")).toBeInTheDocument();
    expect(getByTestId("usage")).toBeInTheDocument();
    const usageElement = getByTestId("usage");
    expect(usageElement.textContent).toBe("1 inked - last used today (10 daily usages)");
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
        created_at="2023-01-01"
        hiddenFields={[
          "brand",
          "model",
          "nib",
          "color",
          "comment",
          "usage",
          "daily_usage",
          "created_at"
        ]}
      />
    );

    expect(queryByText("Pilot")).not.toBeInTheDocument();
    expect(queryByText("Metropolitan")).not.toBeInTheDocument();
    expect(queryByText("CM")).not.toBeInTheDocument();
    expect(queryByText("Black")).not.toBeInTheDocument();
    expect(queryByText("This is a comment")).not.toBeInTheDocument();
    expect(queryByText("Usage")).not.toBeInTheDocument();
    expect(queryByText("Added On")).not.toBeInTheDocument();
  });
});
