import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CreateRow } from "./CreateRow";
import { StateContext, DispatchContext } from "./App";
import { REMOVE_MICRO_CLUSTER } from "./actions";

// Mock the keyDownListener module
jest.mock("./keyDownListener", () => ({
  keyDownListener: jest.fn()
}));

const mockDispatch = jest.fn();
const mockAfterCreate = jest.fn();
const mockCreateMacroClusterAndAssign = jest.fn();
const mockIgnoreCluster = jest.fn();

const { keyDownListener } = require("./keyDownListener");

// Mock window.open
const mockOpen = jest.fn();
Object.defineProperty(window, "open", {
  writable: true,
  value: mockOpen
});

const defaultActiveCluster = {
  id: 1,
  entries: [
    { id: 10, brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" },
    { id: 11, brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" },
    { id: 12, brand: "Pilot", line: "Iroshizuku", name: "Yama-budo" },
    { id: 13, brand: "Pilot", line: "Standard", name: "Blue" }
  ]
};

const defaultState = {
  activeCluster: defaultActiveCluster,
  updating: false
};

const defaultFields = ["brand", "line", "name"];

const renderWithContext = (props = {}, state = defaultState) => {
  const defaultProps = {
    afterCreate: mockAfterCreate,
    createMacroClusterAndAssign: mockCreateMacroClusterAndAssign,
    ignoreCluster: mockIgnoreCluster,
    fields: defaultFields,
    ...props
  };

  return render(
    <StateContext.Provider value={state}>
      <DispatchContext.Provider value={mockDispatch}>
        <table>
          <tbody>
            <CreateRow {...defaultProps} />
          </tbody>
        </table>
      </DispatchContext.Provider>
    </StateContext.Provider>
  );
};

describe("CreateRow", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockIgnoreCluster.mockResolvedValue();
  });

  describe("Rendering", () => {
    it("renders table row with correct structure", () => {
      renderWithContext();

      const row = screen.getByRole("row");
      expect(row).toBeInTheDocument();
    });

    it("renders empty first header cell", () => {
      renderWithContext();

      const headerCells = screen.getAllByRole("columnheader");
      expect(headerCells[0].textContent).toBe("");
    });

    it("renders field values in header cells", () => {
      renderWithContext();

      expect(screen.getByText("Pilot")).toBeInTheDocument();
      expect(screen.getByText("Iroshizuku")).toBeInTheDocument();
      expect(screen.getByText("Tsuki-yo")).toBeInTheDocument();
    });

    it("renders Create button", () => {
      renderWithContext();

      const createButton = screen.getByRole("button", { name: "Create" });
      expect(createButton).toBeInTheDocument();
      expect(createButton).toHaveClass("btn", "btn-success", "me-2");
      expect(createButton).not.toBeDisabled();
    });

    it("renders Ignore button", () => {
      renderWithContext();

      const ignoreButton = screen.getByRole("button", { name: "Ignore" });
      expect(ignoreButton).toBeInTheDocument();
      expect(ignoreButton).toHaveClass("btn", "btn-secondary");
      expect(ignoreButton).not.toBeDisabled();
    });

    it("renders buttons in cell with correct colspan", () => {
      renderWithContext();

      const buttonCell = screen.getByRole("columnheader", { name: /Create/ });
      expect(buttonCell).toHaveAttribute("colSpan", "4");
    });
  });

  describe("Value computation", () => {
    it("computes values from most frequent entry combination", () => {
      renderWithContext();

      // Should show "Pilot Iroshizuku Tsuki-yo" since it appears twice
      expect(screen.getByText("Pilot")).toBeInTheDocument();
      expect(screen.getByText("Iroshizuku")).toBeInTheDocument();
      expect(screen.getByText("Tsuki-yo")).toBeInTheDocument();
    });

    it("handles single entry correctly", () => {
      const singleEntryCluster = {
        id: 1,
        entries: [{ id: 10, brand: "Pilot", line: "Standard", name: "Blue" }]
      };

      renderWithContext({}, { activeCluster: singleEntryCluster, updating: false });

      expect(screen.getByText("Pilot")).toBeInTheDocument();
      expect(screen.getByText("Standard")).toBeInTheDocument();
      expect(screen.getByText("Blue")).toBeInTheDocument();
    });

    it("handles entries with missing field values", () => {
      const clusterWithMissingFields = {
        id: 1,
        entries: [
          { id: 10, brand: "Pilot", name: "Blue" }, // missing line
          { id: 11, brand: "Pilot", name: "Blue" } // missing line
        ]
      };

      renderWithContext({}, { activeCluster: clusterWithMissingFields, updating: false });

      expect(screen.getByText("Pilot")).toBeInTheDocument();
      expect(screen.getByText("Blue")).toBeInTheDocument();
      // The missing line field should show as undefined
      const headerCells = screen.getAllByRole("columnheader");
      expect(headerCells[2].textContent).toBe(""); // undefined renders as empty
    });
  });

  describe("Create functionality", () => {
    it("calls createMacroClusterAndAssign with correct parameters when Create button clicked", async () => {
      const user = userEvent.setup();
      renderWithContext();

      const createButton = screen.getByRole("button", { name: "Create" });
      await user.click(createButton);

      expect(mockCreateMacroClusterAndAssign).toHaveBeenCalledWith(
        { brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" },
        1, // activeCluster.id
        mockDispatch,
        mockAfterCreate
      );
    });

    it("disables Create button when updating is true", () => {
      renderWithContext({}, { ...defaultState, updating: true });

      const createButton = screen.getByRole("button", { name: "Create" });
      expect(createButton).toBeDisabled();
    });
  });

  describe("Ignore functionality", () => {
    it("calls ignoreCluster and dispatches REMOVE_MICRO_CLUSTER when Ignore button clicked", async () => {
      const user = userEvent.setup();
      renderWithContext();

      const ignoreButton = screen.getByRole("button", { name: "Ignore" });
      await user.click(ignoreButton);

      expect(mockIgnoreCluster).toHaveBeenCalledWith(defaultActiveCluster);

      // Due to the implementation bug, dispatch is called immediately, not in promise chain
      expect(mockDispatch).toHaveBeenCalledWith({
        type: REMOVE_MICRO_CLUSTER,
        payload: defaultActiveCluster
      });
    });

    it("disables Ignore button when updating is true", () => {
      renderWithContext({}, { ...defaultState, updating: true });

      const ignoreButton = screen.getByRole("button", { name: "Ignore" });
      expect(ignoreButton).toBeDisabled();
    });
  });

  describe("Keyboard listeners", () => {
    it("sets up keyboard listener on mount", () => {
      renderWithContext();

      expect(keyDownListener).toHaveBeenCalledWith(expect.any(Function));
    });

    it("triggers create when 'C' key is pressed", () => {
      renderWithContext();

      const keyboardHandler = keyDownListener.mock.calls[0][0];
      keyboardHandler({ keyCode: 67 }); // 'C' key

      expect(mockCreateMacroClusterAndAssign).toHaveBeenCalledWith(
        { brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" },
        1,
        mockDispatch,
        mockAfterCreate
      );
    });

    it("opens Google search when 'O' key is pressed", () => {
      renderWithContext();

      const keyboardHandler = keyDownListener.mock.calls[0][0];
      keyboardHandler({ keyCode: 79 }); // 'O' key

      expect(mockOpen).toHaveBeenCalledWith(
        "https://google.com/search?q=Pilot%20Iroshizuku%20Tsuki-yo",
        "_blank"
      );
    });

    it("does not trigger actions for other keys", () => {
      renderWithContext();

      const keyboardHandler = keyDownListener.mock.calls[0][0];
      keyboardHandler({ keyCode: 65 }); // 'A' key

      expect(mockCreateMacroClusterAndAssign).not.toHaveBeenCalled();
      expect(mockOpen).not.toHaveBeenCalled();
    });

    it("cleans up keyboard listener on unmount", () => {
      const mockRemoveListener = jest.fn();
      keyDownListener.mockReturnValue(mockRemoveListener);

      const { unmount } = renderWithContext();
      unmount();

      expect(mockRemoveListener).toHaveBeenCalled();
    });

    it("updates keyboard listener when dependencies change", () => {
      const mockRemoveListener = jest.fn();
      keyDownListener.mockReturnValue(mockRemoveListener);

      const { rerender } = renderWithContext();

      // Re-render with different activeCluster
      const newActiveCluster = {
        id: 2,
        entries: [{ id: 20, brand: "Diamine", line: "Standard", name: "Red" }]
      };

      rerender(
        <StateContext.Provider value={{ activeCluster: newActiveCluster, updating: false }}>
          <DispatchContext.Provider value={mockDispatch}>
            <table>
              <tbody>
                <CreateRow
                  afterCreate={mockAfterCreate}
                  createMacroClusterAndAssign={mockCreateMacroClusterAndAssign}
                  ignoreCluster={mockIgnoreCluster}
                  fields={defaultFields}
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

  describe("Google search functionality", () => {
    it("constructs correct search URL with field values", () => {
      renderWithContext();

      const keyboardHandler = keyDownListener.mock.calls[0][0];
      keyboardHandler({ keyCode: 79 }); // 'O' key

      expect(mockOpen).toHaveBeenCalledWith(
        "https://google.com/search?q=Pilot%20Iroshizuku%20Tsuki-yo",
        "_blank"
      );
    });

    it("handles special characters in search URL", () => {
      const clusterWithSpecialChars = {
        id: 1,
        entries: [
          {
            id: 10,
            brand: "Diamine",
            line: "Standard",
            name: "Writer's Blood & Tears"
          }
        ]
      };

      renderWithContext({}, { activeCluster: clusterWithSpecialChars, updating: false });

      const keyboardHandler = keyDownListener.mock.calls[0][0];
      keyboardHandler({ keyCode: 79 }); // 'O' key

      expect(mockOpen).toHaveBeenCalledWith(
        "https://google.com/search?q=Diamine%20Standard%20Writer's%20Blood%20%26%20Tears",
        "_blank"
      );
    });

    it("handles empty field values in search URL", () => {
      const clusterWithEmptyFields = {
        id: 1,
        entries: [{ id: 10, brand: "Pilot", line: "", name: "Blue" }]
      };

      renderWithContext({}, { activeCluster: clusterWithEmptyFields, updating: false });

      const keyboardHandler = keyDownListener.mock.calls[0][0];
      keyboardHandler({ keyCode: 79 }); // 'O' key

      expect(mockOpen).toHaveBeenCalledWith(
        "https://google.com/search?q=Pilot%20%20Blue",
        "_blank"
      );
    });
  });

  describe("Field rendering", () => {
    it("renders correct number of field headers", () => {
      renderWithContext();

      const headerCells = screen.getAllByRole("columnheader");
      // Should have: empty + 3 fields + buttons = 5 headers
      expect(headerCells).toHaveLength(5);
    });

    it("handles custom fields correctly", () => {
      const customFields = ["brand", "model"];
      const customCluster = {
        id: 1,
        entries: [{ id: 10, brand: "Pilot", model: "Custom 823" }]
      };

      renderWithContext(
        { fields: customFields },
        { activeCluster: customCluster, updating: false }
      );

      expect(screen.getByText("Pilot")).toBeInTheDocument();
      expect(screen.getByText("Custom 823")).toBeInTheDocument();
    });

    it("handles empty fields array", () => {
      renderWithContext({ fields: [] });

      const headerCells = screen.getAllByRole("columnheader");
      // Should have: empty + buttons = 2 headers
      expect(headerCells).toHaveLength(2);
    });
  });
});
