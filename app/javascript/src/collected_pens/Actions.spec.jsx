import React from "react";
import { render, screen } from "@testing-library/react";
import { Actions } from "./Actions";

describe("<Actions />", () => {
  beforeEach(() => {
    render(<Actions />);
  });

  it("includes a link to the import page", () => {
    expect(screen.getByText("Import").href).toMatch("/collected_pens/import");
  });

  it("includes a link to the CSV export", () => {
    expect(screen.getByText("Export").href).toMatch("/collected_pens.csv");
  });

  it("includes a link to the pens archive", () => {
    expect(screen.getByText("Archive").href).toMatch("/collected_pens_archive");
  });

  it("includes a button to add a new pen", () => {
    expect(screen.getByText("Add pen").href).toMatch("/collected_pens/new");
  });
});
