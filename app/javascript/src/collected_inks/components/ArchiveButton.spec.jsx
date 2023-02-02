// @ts-check
import React from "react";
import { render } from "@testing-library/react";
import { ArchiveButton } from "./ArchiveButton";

describe("<ArchiveButton />", () => {
  it("renders a button to archive if archived equals false", () => {
    const { getByRole } = render(
      <ArchiveButton name="Pilot Blue" id="1" archived={false} />
    );

    const link = getByRole("link");

    expect(link.getAttribute("href")).toEqual("/collected_inks/1/archive");
    expect(link.getAttribute("title")).toEqual("Archive Pilot Blue");
  });

  it("renders a button to unarchive if archived equals true", () => {
    const { getByRole } = render(
      <ArchiveButton name="Pilot Blue" id="1" archived={true} />
    );

    const link = getByRole("link");

    expect(link.getAttribute("href")).toEqual("/collected_inks/1/unarchive");
    expect(link.getAttribute("title")).toEqual("Unarchive Pilot Blue");
  });
});
