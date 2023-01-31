// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Actions } from "./Actions";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<Actions />", () => {
  it("renders links and Add ink if not in the archive", () => {
    const { getAllByRole } = setup(
      <Actions
        archive={false}
        activeLayout="table"
        numberOfInks={0}
        onFilterChange={() => {
          return;
        }}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const [importLink, exportLink, archiveLink, addLink] = getAllByRole("link");

    expect(importLink.getAttribute("href")).toEqual("/collected_inks/import");
    expect(exportLink.getAttribute("href")).toEqual("/collected_inks.csv");
    expect(archiveLink.getAttribute("href")).toEqual(
      "/collected_inks?search[archive]=true"
    );
    expect(addLink.getAttribute("href")).toEqual("/collected_inks/new");
  });

  it("renders no links or Add ink if in the archive", () => {
    const { queryAllByRole } = setup(
      <Actions
        archive={true}
        activeLayout="card"
        numberOfInks={0}
        onFilterChange={() => {
          return;
        }}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const links = queryAllByRole("link");

    expect(links).toHaveLength(0);
  });

  it("calls onFilterChange on change for the ink filter input field", async () => {
    const onFilterChange = jest.fn();
    const { user, getByRole } = setup(
      <Actions
        archive={true}
        activeLayout="table"
        numberOfInks={0}
        onFilterChange={onFilterChange}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const input = getByRole("textbox");
    await user.type(input, "p");

    expect(onFilterChange).toHaveBeenCalledWith("p");
  });
});
