import React from "react";
import { render } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Table } from "./Table";

const setup = (jsx, options) => {
  return {
    user: userEvent.setup(),
    ...render(jsx, options)
  };
};

describe("<Table />", () => {
  const mockGetTableProps = () => ({ role: "table" });
  const mockGetTableBodyProps = () => ({});
  const mockGetHeaderGroupProps = () => ({});
  const mockGetFooterGroupProps = () => ({});
  const mockGetHeaderProps = () => ({});
  const mockGetCellProps = () => ({});
  const mockGetRowProps = () => ({});
  const mockGetFooterProps = () => ({});
  const mockGetSortByToggleProps = () => ({ onClick: jest.fn() });

  const mockPrepareRow = jest.fn();

  const headerGroups = [
    {
      getHeaderGroupProps: mockGetHeaderGroupProps,
      headers: [
        {
          getHeaderProps: mockGetHeaderProps,
          getSortByToggleProps: mockGetSortByToggleProps,
          render: (type) => (type === "Header" ? "Name" : null),
          isSorted: false,
          isSortedDesc: false
        },
        {
          getHeaderProps: mockGetHeaderProps,
          getSortByToggleProps: mockGetSortByToggleProps,
          render: (type) => (type === "Header" ? "Age" : null),
          isSorted: true,
          isSortedDesc: false
        },
        {
          getHeaderProps: mockGetHeaderProps,
          getSortByToggleProps: mockGetSortByToggleProps,
          render: (type) => (type === "Header" ? "Email" : null),
          isSorted: true,
          isSortedDesc: true
        }
      ]
    }
  ];

  const rows = [
    {
      getRowProps: mockGetRowProps,
      cells: [
        {
          getCellProps: mockGetCellProps,
          render: (type) => (type === "Cell" ? "John Doe" : null)
        },
        {
          getCellProps: mockGetCellProps,
          render: (type) => (type === "Cell" ? "30" : null)
        },
        {
          getCellProps: mockGetCellProps,
          render: (type) => (type === "Cell" ? "john@example.com" : null)
        }
      ]
    },
    {
      getRowProps: mockGetRowProps,
      cells: [
        {
          getCellProps: mockGetCellProps,
          render: (type) => (type === "Cell" ? "Jane Smith" : null)
        },
        {
          getCellProps: mockGetCellProps,
          render: (type) => (type === "Cell" ? "25" : null)
        },
        {
          getCellProps: mockGetCellProps,
          render: (type) => (type === "Cell" ? "jane@example.com" : null)
        }
      ]
    }
  ];

  const footerGroups = [
    {
      getFooterGroupProps: mockGetFooterGroupProps,
      headers: [
        {
          getFooterProps: mockGetFooterProps,
          render: (type) => (type === "Footer" ? "2 people" : null)
        },
        {
          getFooterProps: mockGetFooterProps,
          render: (type) => (type === "Footer" ? "" : null)
        },
        {
          getFooterProps: mockGetFooterProps,
          render: (type) => (type === "Footer" ? "" : null)
        }
      ]
    }
  ];

  it("renders table structure with thead, tbody, tfoot", () => {
    const { container } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    const table = container.querySelector("table");
    expect(table).toBeInTheDocument();
    expect(table.querySelector("thead")).toBeInTheDocument();
    expect(table.querySelector("tbody")).toBeInTheDocument();
    expect(table.querySelector("tfoot")).toBeInTheDocument();
  });

  it("applies correct CSS classes", () => {
    const { container } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    const wrapper = container.querySelector(".fpc-table");
    expect(wrapper).toHaveClass("fpc-table");
    expect(wrapper).toHaveClass("fpc-table--full-width");
    expect(wrapper).toHaveClass("fpc-scroll-shadow");

    const table = container.querySelector("table");
    expect(table).toHaveClass("table");
    expect(table).toHaveClass("table-striped");
  });

  it("renders all headers from headerGroups", () => {
    const { getByText } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    expect(getByText("Name")).toBeInTheDocument();
    expect(getByText("Age")).toBeInTheDocument();
    expect(getByText("Email")).toBeInTheDocument();
  });

  it("renders all data rows", () => {
    const { getByText } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    expect(getByText("John Doe")).toBeInTheDocument();
    expect(getByText("30")).toBeInTheDocument();
    expect(getByText("john@example.com")).toBeInTheDocument();
    expect(getByText("Jane Smith")).toBeInTheDocument();
    expect(getByText("25")).toBeInTheDocument();
    expect(getByText("jane@example.com")).toBeInTheDocument();
  });

  it("renders footer with aggregations", () => {
    const { getByText } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    expect(getByText("2 people")).toBeInTheDocument();
  });

  it("shows sort indicator for sorted columns", () => {
    const { container } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    const sortIcons = container.querySelectorAll("i.fa");
    expect(sortIcons).toHaveLength(2); // Two sorted columns
  });

  it("shows up arrow for ascending sort", () => {
    const { container } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    const upArrow = container.querySelector("i.fa-arrow-up");
    expect(upArrow).toBeInTheDocument();
  });

  it("shows down arrow for descending sort", () => {
    const { container } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    const downArrow = container.querySelector("i.fa-arrow-down");
    expect(downArrow).toBeInTheDocument();
  });

  it("does not show sort indicator for unsorted columns", () => {
    const { container } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    // First header (Name) should not have a sort icon
    const headerCells = container.querySelectorAll("thead th");
    const nameCell = headerCells[0];
    expect(nameCell.querySelector("i.fa")).not.toBeInTheDocument();
  });

  it("calls prepareRow for each row", () => {
    const localMockPrepareRow = jest.fn();
    setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={localMockPrepareRow}
      />
    );

    expect(localMockPrepareRow).toHaveBeenCalledTimes(2);
    expect(localMockPrepareRow).toHaveBeenCalledWith(rows[0]);
    expect(localMockPrepareRow).toHaveBeenCalledWith(rows[1]);
  });

  it("handles empty data gracefully", () => {
    const { container } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={[]}
        prepareRow={mockPrepareRow}
      />
    );

    const tbody = container.querySelector("tbody");
    expect(tbody).toBeInTheDocument();
    expect(tbody.querySelectorAll("tr")).toHaveLength(0);
  });

  it("applies table props from getTableProps", () => {
    const { container } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    const table = container.querySelector("table");
    expect(table).toHaveAttribute("role", "table");
  });

  it("renders footer with align-top class", () => {
    const { container } = setup(
      <Table
        getTableProps={mockGetTableProps}
        headerGroups={headerGroups}
        footerGroups={footerGroups}
        getTableBodyProps={mockGetTableBodyProps}
        rows={rows}
        prepareRow={mockPrepareRow}
      />
    );

    const footerRow = container.querySelector("tfoot tr");
    expect(footerRow).toHaveClass("align-top");
  });
});
