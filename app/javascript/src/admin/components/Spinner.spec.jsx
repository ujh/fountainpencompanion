import React from "react";
import { render, screen } from "@testing-library/react";
import { Spinner } from "./Spinner";

describe("Spinner", () => {
  it("renders with the correct structure", () => {
    render(<Spinner text="Loading..." />);

    const loader = screen.getByText("Loading...").closest(".loader");
    expect(loader).toBeInTheDocument();
    expect(loader).toHaveClass("loader");
  });

  it("displays the provided text", () => {
    render(<Spinner text="Processing data..." />);

    expect(screen.getByText("Processing data...")).toBeInTheDocument();
  });

  it("renders the spinning icon", () => {
    render(<Spinner text="Loading..." />);

    const icon = document.querySelector(".fa-spin.fa-refresh");
    expect(icon).toBeInTheDocument();
    expect(icon).toHaveClass("fa", "fa-spin", "fa-refresh");
  });

  it("renders correctly with empty text", () => {
    render(<Spinner text="" />);

    const loader = document.querySelector(".loader");
    expect(loader).toBeInTheDocument();

    // Text should still render as empty div
    const textDiv = loader.querySelector("div");
    expect(textDiv).toBeInTheDocument();
    expect(textDiv.textContent).toBe("");
  });

  it("renders correctly with undefined text", () => {
    render(<Spinner />);

    const loader = document.querySelector(".loader");
    expect(loader).toBeInTheDocument();

    // Should still render the structure
    const icon = loader.querySelector(".fa-spin.fa-refresh");
    expect(icon).toBeInTheDocument();
  });

  it("renders with numeric text", () => {
    render(<Spinner text={42.5} />);

    expect(screen.getByText("42.5")).toBeInTheDocument();
  });
});
