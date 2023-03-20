import React from "react";
import { render, screen } from "@testing-library/react";
import { ActionsCell } from "./ActionsCell";

describe("<ActionsCell />", () => {
  beforeEach(() => {
    render(<ActionsCell id={1} />);
  });

  it("includes a link to the edit page", () => {
    expect(screen.getByTitle("edit").href).toMatch("/collected_pens/1/edit");
  });

  it("includes a link to the archive", async () => {
    const button = await screen.getByTitle("archive");
    expect(button.href).toMatch("/collected_pens/1/archive");
    expect(button.getAttribute("data-method")).toBe("post");
  });
});
