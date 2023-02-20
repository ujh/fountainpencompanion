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
        archive={true}
        activeLayout="table"
        numberOfInks={0}
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
        archive={true}
        activeLayout="table"
        numberOfInks={0}
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

    await user.click(getByLabelText("Show private"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["private"]);

    await user.click(getByLabelText("Show maker"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["maker"]);

    await user.click(getByLabelText("Show type"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["kind"]);

    await user.click(getByLabelText("Show swabbed"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["swabbed"]);

    await user.click(getByLabelText("Show used"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["used"]);

    await user.click(getByLabelText("Show usage"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["usage"]);

    await user.click(getByLabelText("Show daily usage"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["daily_usage"]);

    await user.click(getByLabelText("Show comment"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["comment"]);

    await user.click(getByLabelText("Show private comment"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["private_comment"]);

    await user.click(getByLabelText("Show tags"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["tags"]);
  });

  it("calls onHiddenFieldsChange with expected result when turning switch off", async () => {
    const onHiddenFieldsChange = jest.fn();
    const { user, getByTitle, getByLabelText } = setup(
      <Actions
        archive={true}
        activeLayout="table"
        numberOfInks={0}
        hiddenFields={["private"]}
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
    await user.click(getByLabelText("Show private"));

    expect(onHiddenFieldsChange).toHaveBeenCalledWith([]);
  });
});
