import React from "react";
import { render, screen } from "@testing-library/react";
import { DisplayMicroCluster } from "./DisplayMicroCluster";
import { StateContext } from "./App";

// Mock the child components
jest.mock("./CreateRow", () => ({
  CreateRow: ({ afterCreate, createMacroClusterAndAssign, ignoreCluster, fields }) => (
    <tr data-testid="create-row">
      <td>
        CreateRow - afterCreate: {afterCreate ? "present" : "absent"}, createMacroClusterAndAssign:{" "}
        {createMacroClusterAndAssign ? "present" : "absent"}, ignoreCluster:{" "}
        {ignoreCluster ? "present" : "absent"}, fields: {fields.join(",")}
      </td>
    </tr>
  )
}));

jest.mock("./DisplayMacroClusters", () => ({
  DisplayMacroClusters: ({ afterAssign, assignCluster, extraColumn, withDistance, fields }) => (
    <tr data-testid="display-macro-clusters">
      <td>
        DisplayMacroClusters - afterAssign: {afterAssign ? "present" : "absent"}, assignCluster:{" "}
        {assignCluster ? "present" : "absent"}, extraColumn: {extraColumn ? "present" : "absent"},
        withDistance: {withDistance ? "true" : "false"}, fields: {fields.join(",")}
      </td>
    </tr>
  )
}));

jest.mock("./EntriesList", () => ({
  EntriesList: ({ entries, fields, extraColumn }) => (
    <tr data-testid="entries-list">
      <td>
        EntriesList - entries count: {entries.length}, fields: {fields.join(",")}, extraColumn:{" "}
        {extraColumn ? "present" : "absent"}
      </td>
    </tr>
  )
}));

const mockAfterCreate = jest.fn();
const mockAssignCluster = jest.fn();
const mockIgnoreCluster = jest.fn();
const mockExtraColumn = jest.fn();
const mockCreateMacroClusterAndAssign = jest.fn();

const defaultActiveCluster = {
  id: 1,
  entries: [
    { id: 10, brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" },
    { id: 11, brand: "Pilot", line: "Iroshizuku", name: "Yama-budo" },
    { id: 12, brand: "Diamine", line: "Standard", name: "Oxblood" }
  ]
};

const defaultState = {
  activeCluster: defaultActiveCluster
};

const defaultFields = ["brand", "line", "name"];

const renderWithContext = (props = {}, state = defaultState) => {
  const defaultProps = {
    afterCreate: mockAfterCreate,
    assignCluster: mockAssignCluster,
    fields: defaultFields,
    withDistance: true,
    ignoreCluster: mockIgnoreCluster,
    extraColumn: mockExtraColumn,
    createMacroClusterAndAssign: mockCreateMacroClusterAndAssign,
    ...props
  };

  return render(
    <StateContext.Provider value={state}>
      <DisplayMicroCluster {...defaultProps} />
    </StateContext.Provider>
  );
};

describe("DisplayMicroCluster", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe("Structure and Layout", () => {
    it("renders the main container with correct classes", () => {
      const { container } = renderWithContext();

      const mainDiv = container.querySelector(".fpc-table.fpc-table--full-width.fpc-scroll-shadow");
      expect(mainDiv).toBeInTheDocument();
    });

    it("renders a table with correct class", () => {
      renderWithContext();

      const table = document.querySelector("table.table");
      expect(table).toBeInTheDocument();
      expect(table).toHaveClass("table");
    });

    it("renders thead and tbody sections", () => {
      renderWithContext();

      const thead = document.querySelector("thead");
      const tbody = document.querySelector("tbody");

      expect(thead).toBeInTheDocument();
      expect(tbody).toBeInTheDocument();
    });

    it("renders separator row with correct styling", () => {
      const { container } = renderWithContext();

      // Find all table cells and look for the one with black background
      const tableCells = container.querySelectorAll("td");
      const separatorCell = Array.from(tableCells).find(
        (cell) => cell.style.backgroundColor === "black"
      );

      expect(separatorCell).toBeInTheDocument();
      expect(separatorCell).toHaveStyle("background-color: rgb(0, 0, 0)");
    });

    it("sets correct colspan for separator row", () => {
      const { container } = renderWithContext();

      // Find all table cells and look for the one with black background
      const tableCells = container.querySelectorAll("td");
      const separatorCell = Array.from(tableCells).find(
        (cell) => cell.style.backgroundColor === "black"
      );

      expect(separatorCell).toHaveAttribute("colSpan", "8"); // fields.length + 5
    });
  });

  describe("Child Component Rendering", () => {
    it("renders CreateRow in thead", () => {
      renderWithContext();

      const createRow = screen.getByTestId("create-row");
      expect(createRow).toBeInTheDocument();

      const thead = document.querySelector("thead");
      expect(thead).toContainElement(createRow);
    });

    it("renders EntriesList in tbody", () => {
      renderWithContext();

      const entriesList = screen.getByTestId("entries-list");
      expect(entriesList).toBeInTheDocument();

      const tbody = document.querySelector("tbody");
      expect(tbody).toContainElement(entriesList);
    });

    it("renders DisplayMacroClusters in tbody", () => {
      renderWithContext();

      const displayMacroClusters = screen.getByTestId("display-macro-clusters");
      expect(displayMacroClusters).toBeInTheDocument();

      const tbody = document.querySelector("tbody");
      expect(tbody).toContainElement(displayMacroClusters);
    });
  });

  describe("Props Passing", () => {
    it("passes correct props to CreateRow", () => {
      renderWithContext();

      const createRow = screen.getByTestId("create-row");
      expect(createRow).toHaveTextContent("afterCreate: present");
      expect(createRow).toHaveTextContent("createMacroClusterAndAssign: present");
      expect(createRow).toHaveTextContent("ignoreCluster: present");
      expect(createRow).toHaveTextContent("fields: brand,line,name");
    });

    it("passes correct props to EntriesList", () => {
      renderWithContext();

      const entriesList = screen.getByTestId("entries-list");
      expect(entriesList).toHaveTextContent("entries count: 3");
      expect(entriesList).toHaveTextContent("fields: brand,line,name");
      expect(entriesList).toHaveTextContent("extraColumn: present");
    });

    it("passes correct props to DisplayMacroClusters", () => {
      renderWithContext();

      const displayMacroClusters = screen.getByTestId("display-macro-clusters");
      expect(displayMacroClusters).toHaveTextContent("afterAssign: present");
      expect(displayMacroClusters).toHaveTextContent("assignCluster: present");
      expect(displayMacroClusters).toHaveTextContent("extraColumn: present");
      expect(displayMacroClusters).toHaveTextContent("withDistance: true");
      expect(displayMacroClusters).toHaveTextContent("fields: brand,line,name");
    });

    it("passes afterCreate as afterAssign to DisplayMacroClusters", () => {
      const customAfterCreate = jest.fn();
      renderWithContext({ afterCreate: customAfterCreate });

      const displayMacroClusters = screen.getByTestId("display-macro-clusters");
      expect(displayMacroClusters).toHaveTextContent("afterAssign: present");
    });
  });

  describe("Different Field Configurations", () => {
    it("handles custom fields correctly", () => {
      const customFields = ["brand", "model"];
      renderWithContext({ fields: customFields });

      const createRow = screen.getByTestId("create-row");
      const entriesList = screen.getByTestId("entries-list");
      const displayMacroClusters = screen.getByTestId("display-macro-clusters");

      expect(createRow).toHaveTextContent("fields: brand,model");
      expect(entriesList).toHaveTextContent("fields: brand,model");
      expect(displayMacroClusters).toHaveTextContent("fields: brand,model");
    });

    it("updates separator colspan based on fields length", () => {
      const customFields = ["brand"];
      const { container } = renderWithContext({ fields: customFields });

      // Find all table cells and look for the one with black background
      const tableCells = container.querySelectorAll("td");
      const separatorCell = Array.from(tableCells).find(
        (cell) => cell.style.backgroundColor === "black"
      );

      expect(separatorCell).toHaveAttribute("colSpan", "6"); // 1 field + 5
    });

    it("handles empty fields array", () => {
      const { container } = renderWithContext({ fields: [] });

      const createRow = screen.getByTestId("create-row");
      expect(createRow).toHaveTextContent("fields:");

      // Find all table cells and look for the one with black background
      const tableCells = container.querySelectorAll("td");
      const separatorCell = Array.from(tableCells).find(
        (cell) => cell.style.backgroundColor === "black"
      );

      expect(separatorCell).toHaveAttribute("colSpan", "5"); // 0 fields + 5
    });
  });

  describe("ActiveCluster Variations", () => {
    it("handles activeCluster with no entries", () => {
      const emptyCluster = {
        id: 1,
        entries: []
      };

      renderWithContext({}, { activeCluster: emptyCluster });

      const entriesList = screen.getByTestId("entries-list");
      expect(entriesList).toHaveTextContent("entries count: 0");
    });

    it("handles activeCluster with single entry", () => {
      const singleEntryCluster = {
        id: 1,
        entries: [{ id: 10, brand: "Pilot", line: "Iroshizuku", name: "Tsuki-yo" }]
      };

      renderWithContext({}, { activeCluster: singleEntryCluster });

      const entriesList = screen.getByTestId("entries-list");
      expect(entriesList).toHaveTextContent("entries count: 1");
    });

    it("handles activeCluster with many entries", () => {
      const manyEntriesCluster = {
        id: 1,
        entries: new Array(50).fill(null).map((_, i) => ({
          id: i,
          brand: "Brand" + i,
          line: "Line" + i,
          name: "Name" + i
        }))
      };

      renderWithContext({}, { activeCluster: manyEntriesCluster });

      const entriesList = screen.getByTestId("entries-list");
      expect(entriesList).toHaveTextContent("entries count: 50");
    });
  });

  describe("Boolean Props", () => {
    it("handles withDistance as false", () => {
      renderWithContext({ withDistance: false });

      const displayMacroClusters = screen.getByTestId("display-macro-clusters");
      expect(displayMacroClusters).toHaveTextContent("withDistance: false");
    });

    it("handles withDistance as true", () => {
      renderWithContext({ withDistance: true });

      const displayMacroClusters = screen.getByTestId("display-macro-clusters");
      expect(displayMacroClusters).toHaveTextContent("withDistance: true");
    });
  });

  describe("Optional Props", () => {
    it("handles missing optional props gracefully", () => {
      renderWithContext({
        afterCreate: null,
        assignCluster: null,
        ignoreCluster: null,
        extraColumn: null,
        createMacroClusterAndAssign: null
      });

      const createRow = screen.getByTestId("create-row");
      const entriesList = screen.getByTestId("entries-list");
      const displayMacroClusters = screen.getByTestId("display-macro-clusters");

      expect(createRow).toHaveTextContent("afterCreate: absent");
      expect(entriesList).toHaveTextContent("extraColumn: absent");
      expect(displayMacroClusters).toHaveTextContent("afterAssign: absent");
    });
  });

  describe("Component Order", () => {
    it("renders components in correct order", () => {
      const { container } = renderWithContext();

      const tbody = container.querySelector("tbody");
      const children = Array.from(tbody.children);

      // Should be: EntriesList, separator row, DisplayMacroClusters
      expect(children[0]).toHaveAttribute("data-testid", "entries-list");

      // Check if second child has a cell with black background
      const separatorCell = children[1].querySelector("td");
      expect(separatorCell).toHaveStyle("background-color: rgb(0, 0, 0)");

      expect(children[2]).toHaveAttribute("data-testid", "display-macro-clusters");
    });
  });

  describe("CSS Classes", () => {
    it("applies all required CSS classes to container", () => {
      const { container } = renderWithContext();

      const mainDiv = container.firstChild;
      expect(mainDiv).toHaveClass("fpc-table");
      expect(mainDiv).toHaveClass("fpc-table--full-width");
      expect(mainDiv).toHaveClass("fpc-scroll-shadow");
    });

    it("applies table class correctly", () => {
      renderWithContext();

      const table = document.querySelector("table");
      expect(table).toHaveClass("table");
    });
  });
});
