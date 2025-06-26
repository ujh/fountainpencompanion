import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { BrandSelector } from "./BrandSelector";
import { StateContext, DispatchContext } from "./App";
import { UPDATE_SELECTED_BRANDS } from "./actions";

// Mock the keyDownListener module
jest.mock("./keyDownListener", () => ({
  setInBrandSelector: jest.fn()
}));

// Mock react-select to make testing easier
jest.mock("react-select", () => {
  return function MockSelect({ options, onChange, value, onFocus, onBlur }) {
    return (
      <div data-testid="brand-selector">
        <div data-testid="select-element">
          <button
            data-testid="trigger-change"
            onClick={() => {
              // Simulate selecting first option for testing
              const firstOption = options[0];
              if (firstOption) {
                onChange([{ value: firstOption.value, label: firstOption.label }]);
              }
            }}
          >
            Change Selection
          </button>
          <button data-testid="trigger-focus" onClick={onFocus}>
            Focus
          </button>
          <button data-testid="trigger-blur" onClick={onBlur}>
            Blur
          </button>
        </div>
        {/* Display options for testing */}
        <div data-testid="options">
          {options.map((option) => (
            <div key={option.value} data-testid={`option-${option.value}`}>
              {option.label}
            </div>
          ))}
        </div>
        {/* Display current values for testing */}
        <div data-testid="current-values">
          {Array.isArray(value) ? value.map((v) => v.label).join(", ") : value?.label || ""}
        </div>
      </div>
    );
  };
});

const mockDispatch = jest.fn();
const { setInBrandSelector } = require("./keyDownListener");

const renderWithContext = (state, field = "simplified_brand_name") => {
  return render(
    <StateContext.Provider value={state}>
      <DispatchContext.Provider value={mockDispatch}>
        <BrandSelector field={field} />
      </DispatchContext.Provider>
    </StateContext.Provider>
  );
};

describe("BrandSelector", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const mockMicroClusters = [
    { id: 1, simplified_brand_name: "pilot", entries: [] },
    { id: 2, simplified_brand_name: "pilot", entries: [] },
    { id: 3, simplified_brand_name: "diamine", entries: [] },
    { id: 4, simplified_brand_name: "diamine", entries: [] },
    { id: 5, simplified_brand_name: "diamine", entries: [] },
    { id: 6, simplified_brand_name: "aurora", entries: [] }
  ];

  const mockState = {
    microClusters: mockMicroClusters,
    selectedBrands: []
  };

  it("renders with correct structure", () => {
    renderWithContext(mockState);

    expect(screen.getByTestId("brand-selector")).toBeInTheDocument();
    const container = screen.getByTestId("brand-selector").closest(".mb-3");
    expect(container).toHaveClass("mb-3");
  });

  it("generates options from microClusters with counts", () => {
    renderWithContext(mockState);

    expect(screen.getByTestId("option-aurora")).toHaveTextContent("aurora (1)");
    expect(screen.getByTestId("option-diamine")).toHaveTextContent("diamine (3)");
    expect(screen.getByTestId("option-pilot")).toHaveTextContent("pilot (2)");
  });

  it("sorts options alphabetically by label", () => {
    renderWithContext(mockState);

    const optionsContainer = screen.getByTestId("options");
    const optionElements = optionsContainer.querySelectorAll('[data-testid^="option-"]');
    const labels = Array.from(optionElements).map((el) => el.textContent);

    expect(labels).toEqual(["aurora (1)", "diamine (3)", "pilot (2)"]);
  });

  it("uses custom field for grouping", () => {
    const customMicroClusters = [
      { id: 1, custom_field: "value1" },
      { id: 2, custom_field: "value1" },
      { id: 3, custom_field: "value2" }
    ];

    const customState = {
      microClusters: customMicroClusters,
      selectedBrands: []
    };

    renderWithContext(customState, "custom_field");

    expect(screen.getByTestId("option-value1")).toHaveTextContent("value1 (2)");
    expect(screen.getByTestId("option-value2")).toHaveTextContent("value2 (1)");
  });

  it("displays selected brands correctly", () => {
    const stateWithSelection = {
      ...mockState,
      selectedBrands: [
        { value: "pilot", label: "pilot (2)" },
        { value: "diamine", label: "diamine (3)" }
      ]
    };

    renderWithContext(stateWithSelection);

    const currentValues = screen.getByTestId("current-values");
    expect(currentValues.textContent).toBe("pilot (2), diamine (3)");
  });

  it("dispatches UPDATE_SELECTED_BRANDS when selection changes", async () => {
    const user = userEvent.setup();
    renderWithContext(mockState);

    const changeButton = screen.getByTestId("trigger-change");
    await user.click(changeButton);

    expect(mockDispatch).toHaveBeenCalledWith({
      type: UPDATE_SELECTED_BRANDS,
      payload: [{ value: "aurora", label: "aurora (1)" }]
    });
  });

  it("calls setInBrandSelector(true) on focus", async () => {
    const user = userEvent.setup();
    renderWithContext(mockState);

    const focusButton = screen.getByTestId("trigger-focus");
    await user.click(focusButton);

    expect(setInBrandSelector).toHaveBeenCalledWith(true);
  });

  it("calls setInBrandSelector(false) on blur", async () => {
    const user = userEvent.setup();
    renderWithContext(mockState);

    const blurButton = screen.getByTestId("trigger-blur");
    await user.click(blurButton);

    expect(setInBrandSelector).toHaveBeenCalledWith(false);
  });

  it("handles empty microClusters array", () => {
    const emptyState = {
      microClusters: [],
      selectedBrands: []
    };

    renderWithContext(emptyState);

    const optionsContainer = screen.getByTestId("options");
    expect(optionsContainer.children).toHaveLength(0);
  });

  it("handles microClusters with undefined field values", () => {
    const clustersWithUndefined = [
      { id: 1, simplified_brand_name: "pilot" },
      { id: 2 }, // missing simplified_brand_name
      { id: 3, simplified_brand_name: null },
      { id: 4, simplified_brand_name: "pilot" }
    ];

    const stateWithUndefined = {
      microClusters: clustersWithUndefined,
      selectedBrands: []
    };

    renderWithContext(stateWithUndefined);

    const optionsContainer = screen.getByTestId("options");

    // Should group undefined, null, and defined values separately
    expect(optionsContainer.children.length).toBeGreaterThan(0);
    expect(screen.getByTestId("option-pilot")).toHaveTextContent("pilot (2)");
  });

  it("handles microClusters with empty string field values", () => {
    const clustersWithEmpty = [
      { id: 1, simplified_brand_name: "pilot" },
      { id: 2, simplified_brand_name: "" },
      { id: 3, simplified_brand_name: "" },
      { id: 4, simplified_brand_name: "pilot" }
    ];

    const stateWithEmpty = {
      microClusters: clustersWithEmpty,
      selectedBrands: []
    };

    renderWithContext(stateWithEmpty);

    expect(screen.getByTestId("option-pilot")).toHaveTextContent("pilot (2)");
    expect(screen.getByTestId("option-")).toHaveTextContent("(2)"); // empty string group
  });

  it("handles single microCluster correctly", () => {
    const singleClusterState = {
      microClusters: [{ id: 1, simplified_brand_name: "pilot" }],
      selectedBrands: []
    };

    renderWithContext(singleClusterState);

    expect(screen.getByTestId("option-pilot")).toHaveTextContent("pilot (1)");
  });

  it("preserves selection state across re-renders", () => {
    const initialState = {
      ...mockState,
      selectedBrands: [{ value: "pilot", label: "pilot (2)" }]
    };

    const { rerender } = renderWithContext(initialState);

    expect(screen.getByTestId("current-values").textContent).toBe("pilot (2)");

    // Re-render with same state
    rerender(
      <StateContext.Provider value={initialState}>
        <DispatchContext.Provider value={mockDispatch}>
          <BrandSelector field="simplified_brand_name" />
        </DispatchContext.Provider>
      </StateContext.Provider>
    );

    expect(screen.getByTestId("current-values").textContent).toBe("pilot (2)");
  });

  it("updates options when microClusters change", () => {
    const { rerender } = renderWithContext(mockState);

    // Check initial state
    expect(screen.getByTestId("option-pilot")).toHaveTextContent("pilot (2)");

    // Update with different microClusters
    const updatedState = {
      microClusters: [
        { id: 1, simplified_brand_name: "newbrand" },
        { id: 2, simplified_brand_name: "newbrand" }
      ],
      selectedBrands: []
    };

    rerender(
      <StateContext.Provider value={updatedState}>
        <DispatchContext.Provider value={mockDispatch}>
          <BrandSelector field="simplified_brand_name" />
        </DispatchContext.Provider>
      </StateContext.Provider>
    );

    expect(screen.getByTestId("option-newbrand")).toHaveTextContent("newbrand (2)");
  });
});
