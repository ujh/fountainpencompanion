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
  it("shows the expected links", async () => {
    const { getAllByRole } = render(
      <Actions
        activeLayout="table"
        numberOfEntries={0}
        hiddenFields={[]}
        onHiddenFieldsChange={() => {
          return;
        }}
        onFilterChange={() => {
          return;
        }}
        onLayoutChange={() => {
          return;
        }}
      />
    );
    const [exportLink, usageLink, archiveLink, addLink] = getAllByRole("link");

    expect(exportLink.getAttribute("href")).toEqual("/currently_inked.csv");
    expect(usageLink.getAttribute("href")).toEqual("/usage_records");
    expect(archiveLink.getAttribute("href")).toEqual(
      "/currently_inked_archive"
    );
    expect(addLink.getAttribute("href")).toEqual("/currently_inked/new");
  });

  it("calls onFilterChange on change for the filter input field", async () => {
    const onFilterChange = jest.fn();
    const { user, getByRole } = setup(
      <Actions
        activeLayout="table"
        numberOfEntries={0}
        hiddenFields={[]}
        onHiddenFieldsChange={() => {
          return;
        }}
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

  it("calls onFilterChange with undefined when emptied", async () => {
    const onFilterChange = jest.fn();
    const { user, getByRole } = setup(
      <Actions
        activeLayout="table"
        numberOfEntries={0}
        hiddenFields={[]}
        onHiddenFieldsChange={() => {
          return;
        }}
        onFilterChange={onFilterChange}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    const input = getByRole("textbox");
    await user.type(input, "p");

    expect(onFilterChange).toHaveBeenCalledWith("p");

    await user.type(input, "{backspace}");

    expect(onFilterChange).toHaveBeenLastCalledWith(undefined);
  });

  it("calls onHiddenFieldsChange with expected result when turning switch on", async () => {
    const onHiddenFieldsChange = jest.fn();
    const { user, getByTitle, getByLabelText } = setup(
      <Actions
        activeLayout="table"
        numberOfEntries={0}
        hiddenFields={[]}
        onHiddenFieldsChange={onHiddenFieldsChange}
        onFilterChange={() => {
          return;
        }}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    await user.click(getByTitle("Configure visible fields"));

    await user.click(getByLabelText("Show comment"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["comment"]);

    await user.click(getByLabelText("Show pen"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["pen_name"]);

    await user.click(getByLabelText("Show date inked"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["inked_on"]);

    await user.click(getByLabelText("Show last used"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["last_used_on"]);
  });

  it("calls onHiddenFieldsChange with expected result when turning switch off", async () => {
    const onHiddenFieldsChange = jest.fn();
    const { user, getByTitle, getByLabelText } = setup(
      <Actions
        activeLayout="table"
        numberOfEntries={0}
        hiddenFields={["comment"]}
        onHiddenFieldsChange={onHiddenFieldsChange}
        onFilterChange={() => {
          return;
        }}
        onLayoutChange={() => {
          return;
        }}
      />
    );

    await user.click(getByTitle("Configure visible fields"));
    await user.click(getByLabelText("Show comment"));

    expect(onHiddenFieldsChange).toHaveBeenCalledWith([]);
  });
});
