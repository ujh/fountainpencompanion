import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MacroClusterRow } from "./MacroClusterRow";
import { StateContext, DispatchContext } from "./App";
import { ASSIGN_TO_MACRO_CLUSTER, UPDATING } from "./actions";

// Mock the dependencies
jest.mock("react-scroll-into-view-if-needed", () => {
  return function MockScrollIntoViewIfNeeded({ children, active }) {
    return (
      <div data-testid="scroll-into-view" data-active={active}>
        {children}
      </div>
    );
  };
});

jest.mock("./EntriesList", () => ({
  EntriesList: ({ entries }) => (
    <div data-testid="entries-list" data-entries-count={entries.length}>
      Entries List
    </div>
  )
}));

jest.mock("./SearchLink", () => ({
  SearchLink: ({ e }) => (
    <div data-testid="search-link" data-entry-id={e.id}>
      Search Link
    </div>
  )
}));

jest.mock("./keyDownListener", () => ({
  keyDownListener: jest.fn()
}));

const mockDispatch = jest.fn();
const mockAfterAssign = jest.fn();
const mockAssignCluster = jest.fn();
const mockExtraColumn = jest.fn((cluster) => `Extra: ${cluster.id}`);

const { keyDownListener } = require("./keyDownListener");

const defaultMacroCluster = {
  id: 1,
  distance: 0.5,
  brand: "Pilot",
  line: "Iroshizuku",
  name: "Tsuki-yo",
  micro_clusters: [
    {
      id: 10,
      entries: [
        { id: 100, brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" },
        { id: 101, brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" }
      ]
    }
  ]
};

const defaultState = {
  activeCluster: { id: 5 },
  updating: false
};

const defaultFields = ["brand", "line", "name"];

const renderWithContext = (props = {}, state = defaultState) => {
  const defaultProps = {
    macroCluster: defaultMacroCluster,
    afterAssign: mockAfterAssign,
    selected: false,
    assignCluster: mockAssignCluster,
    fields: defaultFields,
    extraColumn: mockExtraColumn,
    ...props
  };

  return render(
    <StateContext.Provider value={state}>
      <DispatchContext.Provider value={mockDispatch}>
        <table>
          <tbody>
            <MacroClusterRow {...defaultProps} />
          </tbody>
        </table>
      </DispatchContext.Provider>
    </StateContext.Provider>
  );
};

describe("MacroClusterRow", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockAssignCluster.mockResolvedValue({ id: 99, type: "micro_cluster" });
  });

  describe("Rendering", () => {
    it("renders the main row with correct structure", () => {
      renderWithContext();

      const rows = screen.getAllByRole("row");
      expect(rows).toHaveLength(1); // Only main row, no expanded view
    });

    it("renders distance in first cell with scroll component", () => {
      renderWithContext();

      const scrollComponent = screen.getByTestId("scroll-into-view");
      expect(scrollComponent).toHaveTextContent("0.5");
      expect(scrollComponent).toHaveAttribute("data-active", "false");
    });

    it("renders field values in correct order", () => {
      renderWithContext();

      expect(screen.getByText("Pilot")).toBeInTheDocument();
      expect(screen.getByText("Iroshizuku")).toBeInTheDocument();
      expect(screen.getByText("Tsuki-yo")).toBeInTheDocument();
    });

    it("renders extra column content", () => {
      renderWithContext();

      expect(mockExtraColumn).toHaveBeenCalledWith(defaultMacroCluster);
      expect(screen.getByText("Extra: 1")).toBeInTheDocument();
    });

    it("renders SearchLink component", () => {
      renderWithContext();

      const searchLink = screen.getByTestId("search-link");
      expect(searchLink).toHaveAttribute("data-entry-id", "1");
    });

    it("renders assign button", () => {
      renderWithContext();

      const assignButton = screen.getByRole("button", { name: "Assign" });
      expect(assignButton).toBeInTheDocument();
      expect(assignButton).toHaveClass("btn", "btn-secondary");
      expect(assignButton).not.toBeDisabled();
    });
  });

  describe("Selected state", () => {
    it("applies selected class when selected is true", () => {
      renderWithContext({ selected: true });

      const rows = screen.getAllByRole("row");
      const mainRow = rows[0];
      expect(mainRow).toHaveClass("selected");
    });

    it("does not apply selected class when selected is false", () => {
      renderWithContext({ selected: false });

      const rows = screen.getAllByRole("row");
      const mainRow = rows[0];
      expect(mainRow).not.toHaveClass("selected");
    });

    it("sets scroll component active when selected", () => {
      renderWithContext({ selected: true });

      const scrollComponent = screen.getByTestId("scroll-into-view");
      expect(scrollComponent).toHaveAttribute("data-active", "true");
    });

    it("shows expanded view when selected even if showInks is false", () => {
      renderWithContext({ selected: true });

      const rows = screen.getAllByRole("row");
      expect(rows).toHaveLength(2); // Main row + expanded row
      expect(screen.getByTestId("entries-list")).toBeInTheDocument();
    });
  });

  describe("Show/Hide inks functionality", () => {
    it("toggles showInks when clicking on distance cell", async () => {
      const user = userEvent.setup();
      renderWithContext();

      const scrollComponent = screen.getByTestId("scroll-into-view");

      // Initially no expanded view
      expect(screen.getAllByRole("row")).toHaveLength(1);

      // Click to show
      await user.click(scrollComponent);
      expect(screen.getAllByRole("row")).toHaveLength(2);
      expect(screen.getByTestId("entries-list")).toBeInTheDocument();

      // Click to hide
      await user.click(scrollComponent);
      expect(screen.getAllByRole("row")).toHaveLength(1);
    });

    it("toggles showInks when clicking on field cells", async () => {
      const user = userEvent.setup();
      renderWithContext();

      const brandCell = screen.getByText("Pilot");

      // Click to show
      await user.click(brandCell);
      expect(screen.getAllByRole("row")).toHaveLength(2);

      // Click to hide
      await user.click(brandCell);
      expect(screen.getAllByRole("row")).toHaveLength(1);
    });

    it("passes correct props to EntriesList when expanded", async () => {
      const user = userEvent.setup();
      renderWithContext();

      const scrollComponent = screen.getByTestId("scroll-into-view");
      await user.click(scrollComponent);

      const entriesList = screen.getByTestId("entries-list");
      expect(entriesList).toHaveAttribute("data-entries-count", "2");
    });
  });

  describe("Assign functionality", () => {
    it("calls assignCluster with correct parameters when assign button clicked", async () => {
      const user = userEvent.setup();
      renderWithContext();

      const assignButton = screen.getByRole("button", { name: "Assign" });
      await user.click(assignButton);

      // Wait for the setTimeout delay in the component
      await waitFor(() => {
        expect(mockAssignCluster).toHaveBeenCalledWith(5, 1); // activeCluster.id, macroCluster.id
      });
    });

    it("dispatches UPDATING action immediately when assign button clicked", async () => {
      const user = userEvent.setup();
      renderWithContext();

      const assignButton = screen.getByRole("button", { name: "Assign" });
      await user.click(assignButton);

      expect(mockDispatch).toHaveBeenCalledWith({ type: UPDATING });
    });

    it("dispatches ASSIGN_TO_MACRO_CLUSTER after successful assignment", async () => {
      const user = userEvent.setup();
      const expectedMicroCluster = { id: 99, type: "micro_cluster" };
      mockAssignCluster.mockResolvedValue(expectedMicroCluster);

      renderWithContext();

      const assignButton = screen.getByRole("button", { name: "Assign" });
      await user.click(assignButton);

      await waitFor(() => {
        expect(mockDispatch).toHaveBeenCalledWith({
          type: ASSIGN_TO_MACRO_CLUSTER,
          payload: expectedMicroCluster
        });
      });
    });

    it("calls afterAssign callback after successful assignment", async () => {
      const user = userEvent.setup();
      const expectedMicroCluster = { id: 99, type: "micro_cluster" };
      mockAssignCluster.mockResolvedValue(expectedMicroCluster);

      renderWithContext();

      const assignButton = screen.getByRole("button", { name: "Assign" });
      await user.click(assignButton);

      await waitFor(() => {
        expect(mockAfterAssign).toHaveBeenCalledWith(expectedMicroCluster);
      });
    });

    it("disables assign button when updating is true", () => {
      renderWithContext({}, { ...defaultState, updating: true });

      const assignButton = screen.getByRole("button", { name: "Assign" });
      expect(assignButton).toBeDisabled();
    });
  });

  describe("Keyboard listener", () => {
    it("sets up keyboard listener when selected", () => {
      renderWithContext({ selected: true });

      expect(keyDownListener).toHaveBeenCalledWith(expect.any(Function));
    });

    it("does not set up keyboard listener when not selected", () => {
      renderWithContext({ selected: false });

      expect(keyDownListener).not.toHaveBeenCalled();
    });

    it("triggers assign when 'a' key is pressed and selected", async () => {
      const mockRemoveListener = jest.fn();
      keyDownListener.mockReturnValue(mockRemoveListener);

      renderWithContext({ selected: true });

      // Get the keyboard handler function
      const keyboardHandler = keyDownListener.mock.calls[0][0];

      // Call it with keyCode 65 (letter 'a')
      keyboardHandler({ keyCode: 65 });

      expect(mockDispatch).toHaveBeenCalledWith({ type: UPDATING });

      // Wait for the setTimeout delay in the component
      await waitFor(() => {
        expect(mockAssignCluster).toHaveBeenCalledWith(5, 1);
      });
    });

    it("does not trigger assign when other keys are pressed", () => {
      const mockRemoveListener = jest.fn();
      keyDownListener.mockReturnValue(mockRemoveListener);

      renderWithContext({ selected: true });

      const keyboardHandler = keyDownListener.mock.calls[0][0];

      // Call with different keyCode
      keyboardHandler({ keyCode: 66 }); // letter 'b'

      expect(mockAssignCluster).not.toHaveBeenCalled();
    });

    it("cleans up keyboard listener on unmount", () => {
      const mockRemoveListener = jest.fn();
      keyDownListener.mockReturnValue(mockRemoveListener);

      const { unmount } = renderWithContext({ selected: true });

      unmount();

      expect(mockRemoveListener).toHaveBeenCalled();
    });

    it("updates keyboard listener when dependencies change", () => {
      const mockRemoveListener = jest.fn();
      keyDownListener.mockReturnValue(mockRemoveListener);

      const { rerender } = renderWithContext({ selected: true });

      expect(keyDownListener).toHaveBeenCalledTimes(1);

      // Re-render with different activeCluster
      rerender(
        <StateContext.Provider value={{ ...defaultState, activeCluster: { id: 6 } }}>
          <DispatchContext.Provider value={mockDispatch}>
            <table>
              <tbody>
                <MacroClusterRow
                  macroCluster={defaultMacroCluster}
                  afterAssign={mockAfterAssign}
                  selected={true}
                  assignCluster={mockAssignCluster}
                  fields={defaultFields}
                  extraColumn={mockExtraColumn}
                />
              </tbody>
            </table>
          </DispatchContext.Provider>
        </StateContext.Provider>
      );

      expect(mockRemoveListener).toHaveBeenCalled();
      expect(keyDownListener).toHaveBeenCalledTimes(2);
    });
  });

  describe("Expanded view", () => {
    it("renders expanded row with correct colspan", async () => {
      const user = userEvent.setup();
      renderWithContext();

      const scrollComponent = screen.getByTestId("scroll-into-view");
      await user.click(scrollComponent);

      const rows = screen.getAllByRole("row");
      const expandedRow = rows[1];
      const cell = expandedRow.querySelector("td");

      expect(cell).toHaveAttribute("colspan", "8"); // fields.length + 5
    });

    it("renders nested table with correct class", async () => {
      const user = userEvent.setup();
      renderWithContext();

      const scrollComponent = screen.getByTestId("scroll-into-view");
      await user.click(scrollComponent);

      const nestedTable = document.querySelector(".table.macro-cluster-collected-inks");
      expect(nestedTable).toBeInTheDocument();
    });

    it("flattens micro cluster entries for EntriesList", async () => {
      const user = userEvent.setup();
      const macroClusterWithMultipleMicroClusters = {
        ...defaultMacroCluster,
        micro_clusters: [
          {
            id: 10,
            entries: [{ id: 100 }, { id: 101 }]
          },
          {
            id: 11,
            entries: [{ id: 102 }, { id: 103 }, { id: 104 }]
          }
        ]
      };

      renderWithContext({ macroCluster: macroClusterWithMultipleMicroClusters });

      const scrollComponent = screen.getByTestId("scroll-into-view");
      await user.click(scrollComponent);

      const entriesList = screen.getByTestId("entries-list");
      expect(entriesList).toHaveAttribute("data-entries-count", "5");
    });
  });

  describe("Error handling", () => {
    it("handles assignCluster promise rejection gracefully", async () => {
      const user = userEvent.setup();
      const consoleErrorSpy = jest.spyOn(console, "error").mockImplementation(() => {});
      mockAssignCluster.mockRejectedValue(new Error("Assignment failed"));

      renderWithContext();

      const assignButton = screen.getByRole("button", { name: "Assign" });
      await user.click(assignButton);

      // Wait a bit to let any promises settle, then verify component is still intact
      await waitFor(() => {
        expect(screen.getByRole("button", { name: "Assign" })).toBeInTheDocument();
      });

      consoleErrorSpy.mockRestore();
    });
  });

  describe("Edge cases", () => {
    it("handles empty micro_clusters array", async () => {
      const user = userEvent.setup();
      const macroClusterWithoutMicroClusters = {
        ...defaultMacroCluster,
        micro_clusters: []
      };

      renderWithContext({ macroCluster: macroClusterWithoutMicroClusters });

      const scrollComponent = screen.getByTestId("scroll-into-view");
      await user.click(scrollComponent);

      const entriesList = screen.getByTestId("entries-list");
      expect(entriesList).toHaveAttribute("data-entries-count", "0");
    });

    it("handles missing field values", () => {
      const macroClusterWithMissingFields = {
        id: 1,
        distance: 0.5,
        brand: "Pilot",
        // missing line and name
        micro_clusters: []
      };

      renderWithContext({ macroCluster: macroClusterWithMissingFields });

      expect(screen.getByText("Pilot")).toBeInTheDocument();
      // Should still render cells for missing fields (empty)
      const cells = document.querySelectorAll("td");
      expect(cells.length).toBeGreaterThan(3);
    });
  });
});
