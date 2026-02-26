import React from "react";
import { render, screen, fireEvent } from "@testing-library/react";
import { App } from "edit-colors/app";

describe("EditColors App", () => {
  const defaultProps = {
    colors: ["#ff0000", "#00ff00", "#0000ff"],
    ignoredColors: ["#0000ff"],
    submitUrl: "/brands/1/inks/1",
    cancelUrl: "/brands/1/inks/1",
    currentColor: "#aabbcc",
    csrfToken: "test-token"
  };

  it("renders colors to keep and colors to ignore sections", () => {
    render(<App {...defaultProps} />);
    expect(screen.getByText("Colors to keep")).toBeTruthy();
    expect(screen.getByText("Colors to ignore")).toBeTruthy();
  });

  it("shows kept colors as clickable tiles", () => {
    render(<App {...defaultProps} />);
    const keptTiles = screen.getAllByTitle(/Click to ignore/);
    expect(keptTiles).toHaveLength(2);
  });

  it("shows ignored colors as clickable tiles", () => {
    render(<App {...defaultProps} />);
    const ignoredTiles = screen.getAllByTitle(/Click to keep/);
    expect(ignoredTiles).toHaveLength(1);
  });

  it("moves a color from keep to ignore on click", () => {
    render(<App {...defaultProps} />);
    const redTile = screen.getByTitle("Click to ignore #ff0000");
    fireEvent.click(redTile);
    expect(screen.getAllByTitle(/Click to keep/)).toHaveLength(2);
    // Only one kept color remains, so it shows as disabled
    expect(screen.getByTitle(/#00ff00 \(cannot ignore last color\)/)).toBeTruthy();
  });

  it("moves a color from ignore to keep on click", () => {
    render(<App {...defaultProps} />);
    const blueTile = screen.getByTitle("Click to keep #0000ff");
    fireEvent.click(blueTile);
    expect(screen.getAllByTitle(/Click to ignore/)).toHaveLength(3);
    expect(screen.queryAllByTitle(/Click to keep/)).toHaveLength(0);
  });

  it("renders stale ignored colors as non-clickable", () => {
    const props = {
      ...defaultProps,
      ignoredColors: ["#0000ff", "#abcdef"]
    };
    render(<App {...props} />);
    const staleTile = screen.getByTitle("#abcdef (no longer in collected inks)");
    expect(staleTile.className).toContain("stale");
  });

  it("includes hidden inputs for ignored colors in the form", () => {
    const { container } = render(<App {...defaultProps} />);
    const hiddenInputs = container.querySelectorAll(
      'input[name="macro_cluster[ignored_colors][]"]'
    );
    const values = Array.from(hiddenInputs).map((i) => i.value);
    expect(values).toContain("#0000ff");
  });

  it("prevents ignoring the last kept color", () => {
    const props = {
      ...defaultProps,
      colors: ["#ff0000", "#00ff00", "#0000ff"],
      ignoredColors: ["#00ff00", "#0000ff"]
    };
    render(<App {...props} />);
    // Only one kept color remains
    const lastTile = screen.getByTitle("#ff0000 (cannot ignore last color)");
    fireEvent.click(lastTile);
    // Should still be in "keep" — no "Click to keep" tiles should appear for it
    expect(screen.getByTitle("#ff0000 (cannot ignore last color)")).toBeTruthy();
  });

  it("renders cancel link with correct URL", () => {
    render(<App {...defaultProps} />);
    const cancelLink = screen.getByText("Cancel");
    expect(cancelLink.getAttribute("href")).toBe("/brands/1/inks/1");
  });

  it("renders current and new color previews", () => {
    render(<App {...defaultProps} />);
    expect(screen.getByText("Current")).toBeTruthy();
    expect(screen.getByText("New")).toBeTruthy();
  });
});
