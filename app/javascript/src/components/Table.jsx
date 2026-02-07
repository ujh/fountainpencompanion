import React from "react";
import { flexRender } from "@tanstack/react-table";

export const Table = ({
  getTableProps,
  headerGroups,
  footerGroups,
  getTableBodyProps,
  rows,
  prepareRow
}) => (
  <div className="fpc-table fpc-table--full-width fpc-scroll-shadow">
    <table {...getTableProps()} className="table table-striped">
      <thead>
        {headerGroups.map((headerGroup, i) => (
          <tr key={`thead-tr-${i}`} {...headerGroup.getHeaderGroupProps()}>
            {headerGroup.headers.map((column, j) => (
              <th
                key={`thead-th-${i}-${j}`}
                {...column.getHeaderProps(column.getSortByToggleProps())}
              >
                {column.columnDef?.header
                  ? flexRender(column.columnDef.header, column.getContext?.() ?? {})
                  : column.render("Header")}
                <span>
                  &nbsp;
                  {(column.getIsSorted ? column.getIsSorted() : column.isSorted) ? (
                    <i
                      className={`fa fa-arrow-${column.getIsSorted?.() === "desc" || column.isSortedDesc ? "down" : "up"}`}
                    />
                  ) : (
                    ""
                  )}
                </span>
              </th>
            ))}
          </tr>
        ))}
      </thead>
      <tbody {...getTableBodyProps()}>
        {rows.map((row, i) => {
          prepareRow(row);
          return (
            <tr key={`tbody-tr-${i}`} {...row.getRowProps()}>
              {row.cells.map((cell, j) => {
                return (
                  <td key={`thead-td-${i}-${j}`} {...cell.getCellProps()}>
                    {cell.column?.columnDef?.cell
                      ? flexRender(cell.column.columnDef.cell, cell.getContext?.() ?? {})
                      : cell.render("Cell")}
                  </td>
                );
              })}
            </tr>
          );
        })}
      </tbody>
      <tfoot>
        {footerGroups.map((group, i) => (
          <tr key={`tfoot-tr-${i}`} className="align-top" {...group.getFooterGroupProps()}>
            {group.headers.map((column, j) => (
              <td key={`tfoot-td-${i}-${j}`} {...column.getFooterProps()}>
                {column.columnDef?.footer
                  ? flexRender(column.columnDef.footer, column.getContext?.() ?? {})
                  : column.render("Footer")}
              </td>
            ))}
          </tr>
        ))}
      </tfoot>
    </table>
  </div>
);
