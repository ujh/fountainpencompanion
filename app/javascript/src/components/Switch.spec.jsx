// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Switch } from "./Switch";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<Switch />", () => {
  it("calls onChange when clicked", async () => {
    let checked = false;

    const { user, getByRole } = setup(
      <Switch checked={false} onChange={(e) => (checked = e.target.checked)}>
        Comments
      </Switch>
    );

    const input = getByRole("switch");
    await user.click(input);

    expect(checked).toBe(true);
  });

  it("returns expected value when starting checked", async () => {
    let checked = true;

    const { user, getByRole } = setup(
      <Switch checked={true} onChange={(e) => (checked = e.target.checked)}>
        Comments
      </Switch>
    );

    const input = getByRole("switch");
    await user.click(input);

    expect(checked).toBe(false);
  });
});
