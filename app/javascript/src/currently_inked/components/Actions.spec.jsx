import React from "react";
import { render, screen } from "@testing-library/react";
import { Actions } from "./Actions";

describe("<Actions />", () => {
  it("shows the export button", async () => {
    render(<Actions />);
    const button = await screen.findByText("Export");
    expect(button.getAttribute("href")).toEqual("/currently_inked.csv");
  });

  it("shows the usage button", async () => {
    render(<Actions />);
    const button = await screen.findByText("Usage");
    expect(button.getAttribute("href")).toEqual("/usage_records");
  });

  it("shows the archive button", async () => {
    render(<Actions />);
    const button = await screen.findByText("Archive");
    expect(button.getAttribute("href")).toEqual("/currently_inked_archive");
  });

  it("shows the add button", async () => {
    render(<Actions />);
    const button = await screen.findByText("Add entry");
    expect(button.getAttribute("href")).toEqual("/currently_inked/new");
  });
});
