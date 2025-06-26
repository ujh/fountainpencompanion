import React from "react";
import { render, screen } from "@testing-library/react";
import { Summary } from "./Summary";
import { StateContext } from "./App";

const renderWithContext = (contextValue) => {
  return render(
    <StateContext.Provider value={contextValue}>
      <Summary />
    </StateContext.Provider>
  );
};

describe("Summary", () => {
  it("renders with correct structure and class", () => {
    const mockState = {
      microClusters: [{ id: 1 }, { id: 2 }],
      selectedMicroClusters: [{ id: 1 }]
    };

    renderWithContext(mockState);

    const summaryDiv = document.querySelector(".summary");
    expect(summaryDiv).toBeInTheDocument();
    expect(summaryDiv).toHaveClass("summary");
  });

  it("displays correct counts for microClusters and selectedMicroClusters", () => {
    const mockState = {
      microClusters: [{ id: 1 }, { id: 2 }, { id: 3 }],
      selectedMicroClusters: [{ id: 1 }, { id: 2 }]
    };

    renderWithContext(mockState);

    expect(screen.getByText("Total:")).toBeInTheDocument();
    expect(screen.getByText(/3/)).toBeInTheDocument();
    expect(screen.getByText("In Selection:")).toBeInTheDocument();
    expect(screen.getByText(/2/)).toBeInTheDocument();
  });

  it("displays zero counts when arrays are empty", () => {
    const mockState = {
      microClusters: [],
      selectedMicroClusters: []
    };

    renderWithContext(mockState);

    expect(screen.getByText("Total:")).toBeInTheDocument();
    expect(screen.getByText(/0/)).toBeInTheDocument();
    expect(screen.getByText("In Selection:")).toBeInTheDocument();
    // Both zeros appear in the same div, so we check the text content structure
    const summaryDiv = document.querySelector(".summary");
    expect(summaryDiv.textContent).toContain("Total: 0");
    expect(summaryDiv.textContent).toContain("In Selection: 0");
  });

  it("displays correct count when selectedMicroClusters is empty", () => {
    const mockState = {
      microClusters: [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 }],
      selectedMicroClusters: []
    };

    renderWithContext(mockState);

    expect(screen.getByText("Total:")).toBeInTheDocument();
    expect(screen.getByText(/5/)).toBeInTheDocument();
    expect(screen.getByText("In Selection:")).toBeInTheDocument();
    expect(screen.getByText(/0/)).toBeInTheDocument();
  });

  it("displays correct count when all microClusters are selected", () => {
    const mockState = {
      microClusters: [{ id: 1 }, { id: 2 }],
      selectedMicroClusters: [{ id: 1 }, { id: 2 }]
    };

    renderWithContext(mockState);

    expect(screen.getByText("Total:")).toBeInTheDocument();
    // Both 2s appear in the same div, so we check the text content structure
    const summaryDiv = document.querySelector(".summary");
    expect(summaryDiv.textContent).toContain("Total: 2");
    expect(summaryDiv.textContent).toContain("In Selection: 2");
    expect(screen.getByText("In Selection:")).toBeInTheDocument();
  });

  it("handles large numbers correctly", () => {
    const mockState = {
      microClusters: new Array(1000).fill(null).map((_, i) => ({ id: i })),
      selectedMicroClusters: new Array(500).fill(null).map((_, i) => ({ id: i }))
    };

    renderWithContext(mockState);

    expect(screen.getByText("Total:")).toBeInTheDocument();
    expect(screen.getByText(/1000/)).toBeInTheDocument();
    expect(screen.getByText("In Selection:")).toBeInTheDocument();
    expect(screen.getByText(/500/)).toBeInTheDocument();
  });

  it("renders bold labels correctly", () => {
    const mockState = {
      microClusters: [{ id: 1 }],
      selectedMicroClusters: [{ id: 1 }]
    };

    renderWithContext(mockState);

    const totalLabel = screen.getByText("Total:");
    const selectionLabel = screen.getByText("In Selection:");

    expect(totalLabel.tagName).toBe("B");
    expect(selectionLabel.tagName).toBe("B");
  });

  it("maintains correct text structure", () => {
    const mockState = {
      microClusters: [{ id: 1 }, { id: 2 }],
      selectedMicroClusters: [{ id: 1 }]
    };

    renderWithContext(mockState);

    const summaryDiv = document.querySelector(".summary");
    expect(summaryDiv.textContent).toBe("Total: 2 In Selection: 1");
  });
});
