// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LayoutToggle } from "./LayoutToggle";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<LayoutToggle />", () => {
  it("calls onChange with the expected value when the active layout is table", async () => {
    const onChange = jest.fn((e) => e.target.value);

    const { user, getAllByRole } = setup(
      <LayoutToggle activeLayout="table" onChange={onChange} />
    );

    const [, card] = getAllByRole("radio");

    await user.click(card);

    expect(onChange).toHaveReturnedWith("card");
  });

  it("calls onChange with the expected value when the active layout is card", async () => {
    const onChange = jest.fn((e) => e.target.value);

    const { user, getAllByRole } = setup(
      <LayoutToggle activeLayout="card" onChange={onChange} />
    );

    const [table] = getAllByRole("radio");

    await user.click(table);

    expect(onChange).toHaveReturnedWith("table");
  });
});
