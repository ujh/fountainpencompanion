import React from "react";
import { render } from "@testing-library/react";
import { LoadingOverlay } from "./LoadingOverlay";
import { StateContext } from "./App";

const renderWithContext = (contextValue) => {
  return render(
    <StateContext.Provider value={contextValue}>
      <LoadingOverlay />
    </StateContext.Provider>
  );
};

describe("LoadingOverlay", () => {
  it("renders nothing when updating is false", () => {
    const mockState = {
      updating: false
    };

    const { container } = renderWithContext(mockState);
    expect(container.firstChild).toBeNull();
  });

  it("renders nothing when updating is null", () => {
    const mockState = {
      updating: null
    };

    const { container } = renderWithContext(mockState);
    expect(container.firstChild).toBeNull();
  });

  it("renders nothing when updating is undefined", () => {
    const mockState = {
      updating: undefined
    };

    const { container } = renderWithContext(mockState);
    expect(container.firstChild).toBeNull();
  });

  it("renders overlay div when updating is true", () => {
    const mockState = {
      updating: true
    };

    const { container } = renderWithContext(mockState);
    const overlay = container.firstChild;

    expect(overlay).toBeInTheDocument();
    expect(overlay.tagName).toBe("DIV");
  });

  it("applies correct styles when updating is true", () => {
    const mockState = {
      updating: true
    };

    const { container } = renderWithContext(mockState);
    const overlay = container.firstChild;

    expect(overlay).toHaveStyle({
      position: "fixed",
      top: "0",
      left: "0",
      height: "100%",
      width: "100%",
      zIndex: "10",
      backgroundColor: "rgba(0,0,0,0.5)"
    });
  });

  it("renders overlay for any truthy updating value", () => {
    const truthyValues = [true, 1, "loading", {}, []];

    truthyValues.forEach((value) => {
      const mockState = { updating: value };
      const { container } = renderWithContext(mockState);
      const overlay = container.firstChild;

      expect(overlay).toBeInTheDocument();
      expect(overlay.tagName).toBe("DIV");
    });
  });

  it("does not render overlay for falsy updating values", () => {
    const falsyValues = [false, 0, "", null, undefined];

    falsyValues.forEach((value) => {
      const mockState = { updating: value };
      const { container } = renderWithContext(mockState);

      expect(container.firstChild).toBeNull();
    });
  });

  it("creates full-screen overlay with semi-transparent background", () => {
    const mockState = {
      updating: true
    };

    const { container } = renderWithContext(mockState);
    const overlay = container.firstChild;

    // Check that it covers the entire viewport
    expect(overlay).toHaveStyle("position: fixed");
    expect(overlay).toHaveStyle("top: 0");
    expect(overlay).toHaveStyle("left: 0");
    expect(overlay).toHaveStyle("height: 100%");
    expect(overlay).toHaveStyle("width: 100%");

    // Check that it's above other content
    expect(overlay).toHaveStyle("zIndex: 10");

    // Check semi-transparent black background
    expect(overlay).toHaveStyle("backgroundColor: rgba(0,0,0,0.5)");
  });

  it("re-renders correctly when updating state changes", () => {
    const mockState = {
      updating: false
    };

    const { container, rerender } = renderWithContext(mockState);
    expect(container.firstChild).toBeNull();

    // Update to show overlay
    rerender(
      <StateContext.Provider value={{ updating: true }}>
        <LoadingOverlay />
      </StateContext.Provider>
    );
    expect(container.firstChild).toBeInTheDocument();

    // Update to hide overlay
    rerender(
      <StateContext.Provider value={{ updating: false }}>
        <LoadingOverlay />
      </StateContext.Provider>
    );
    expect(container.firstChild).toBeNull();
  });
});
