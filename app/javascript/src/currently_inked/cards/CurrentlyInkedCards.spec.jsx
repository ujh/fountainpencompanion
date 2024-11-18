// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import {
  CurrentlyInkedCards,
  storageKeyHiddenFields
} from "./CurrentlyInkedCards";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<CurrentlyInkedCards />", () => {
  const currentlyInked = [
    {
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
      collected_ink: { color: "#ac54b5" },
      collected_pen: { model_variant_id: 123 }
    }
  ];

  beforeEach(() => {
    localStorage.clear();
  });

  it("renders", async () => {
    const { findByText } = setup(
      <CurrentlyInkedCards
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
      <CurrentlyInkedCards
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryByText("Sailor Pro Gear, Black, M")).toBeInTheDocument();

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show pen"));

    expect(queryByText("Sailor Pro Gear, Black, M")).not.toBeInTheDocument();
  });

  it("resets hidden fields when restore defaults is clicked", async () => {
    const { getByText, getByTitle, getByLabelText, queryByText, user } = setup(
      <CurrentlyInkedCards
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show pen"));

    expect(queryByText("Sailor Pro Gear, Black, M")).not.toBeInTheDocument();

    await user.click(getByText("Restore defaults"));

    expect(queryByText("Sailor Pro Gear, Black, M")).toBeInTheDocument();
  });

  it("renders with hidden fields restored from localStorage", () => {
    localStorage.setItem(storageKeyHiddenFields, JSON.stringify(["pen_name"]));

    const { queryByText } = setup(
      <CurrentlyInkedCards
        currentlyInked={currentlyInked}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    expect(queryByText("Sailor Pro Gear, Black, M")).not.toBeInTheDocument();
  });
});
