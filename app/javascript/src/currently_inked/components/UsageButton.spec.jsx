// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { UsageButton } from "./UsageButton";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<UsageButton />", () => {
  it("shows the correct button when used_today is true", async () => {
    const { findByTitle } = setup(<UsageButton used={true} id={1} />);
    const button = await findByTitle("Already recorded usage for today");
    expect(button).toBeInTheDocument();
  });

  it("shows the correct button when used_today is false", async () => {
    const { findByTitle } = setup(<UsageButton used={false} id={1} />);
    const button = await findByTitle("Record usage for today");
    expect(button).toBeInTheDocument();
    expect(button.getAttribute("href")).toEqual(
      "/currently_inked/1/usage_record"
    );
  });

  it("shows the correct button after clicking on it", async () => {
    const { user, findByTitle } = setup(
      <UsageButton used={false} id={1} testingMode={true} />
    );
    const button = await findByTitle("Record usage for today");
    await user.click(button);
    const newButton = await findByTitle("Already recorded usage for today");
    expect(newButton).toBeInTheDocument();
  });
});
