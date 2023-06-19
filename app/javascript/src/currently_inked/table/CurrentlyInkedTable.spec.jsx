import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import {
  CurrentlyInkedTable,
  storageKeyHiddenFields
} from "./CurrentlyInkedTable";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<CurrentlyInkedTable />", () => {
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
      collected_ink: { color: "#ac54b5" }
    },
    {
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
      collected_ink: { color: "#000" }
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
});
