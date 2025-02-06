// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import { EditButton } from "./EditButton";

describe("<EditButton />", () => {
  it("renders a button to archive if archived equals false", () => {
    const { getByRole } = render(<EditButton name="Pilot Blue" id="1" archived={false} />);

    const link = getByRole("link");

    expect(link.getAttribute("href")).toEqual("/collected_inks/1/edit");
    expect(link.getAttribute("title")).toEqual("Edit Pilot Blue");
  });

  it("renders a button to unarchive if archived equals true", () => {
    const { getByRole } = render(<EditButton name="Pilot Blue" id="1" archived={true} />);

    const link = getByRole("link");

    expect(link.getAttribute("href")).toEqual("/collected_inks/1/edit?search[archive]=true");
    expect(link.getAttribute("title")).toEqual("Edit Pilot Blue");
  });
});
