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
  it("includes the expected links", () => {
    const { getByText } = setup(
      <Actions
        activeLayout="table"
        numberOfPens={0}
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
    expect(getByText("Import").href).toMatch("/collected_pens/import");

    expect(getByText("Export").href).toMatch("/collected_pens.csv");

    expect(getByText("Archive").href).toMatch("/collected_pens_archive");

    expect(getByText("Add pen").href).toMatch("/collected_pens/new");
  });

  it("calls onFilterChange on change for the ink filter input field", async () => {
    const onFilterChange = jest.fn();
    const { user, getByRole } = setup(
      <Actions
        activeLayout="table"
        numberOfPens={0}
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
        numberOfPens={0}
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
        numberOfPens={0}
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

    await user.click(getByLabelText("Show nib"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["nib"]);

    await user.click(getByLabelText("Show color"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["color"]);

    await user.click(getByLabelText("Show usage"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["usage"]);

    await user.click(getByLabelText("Show daily usage"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["daily_usage"]);

    await user.click(getByLabelText("Show comment"));
    expect(onHiddenFieldsChange).toHaveBeenCalledWith(["comment"]);
  });

  it("calls onHiddenFieldsChange with expected result when turning switch off", async () => {
    const onHiddenFieldsChange = jest.fn();
    const { user, getByTitle, getByLabelText } = setup(
      <Actions
        activeLayout="table"
        numberOfPens={0}
        hiddenFields={["nib"]}
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
    await user.click(getByLabelText("Show nib"));

    expect(onHiddenFieldsChange).toHaveBeenCalledWith([]);
  });
});
