import React from "react";
import { ActionsCell } from "./ActionsCell";

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
                {column.render("Header")}
                <span>
                  &nbsp;
                  {column.isSorted ? (
                    <i
                      className={`fa fa-arrow-${
                        column.isSortedDesc ? "down" : "up"
                      }`}
                    />
                  ) : (
                    ""
                  )}
                </span>
              </th>
            ))}
            <th>Actions</th>
          </tr>
        ))}
      </thead>
      <tbody {...getTableBodyProps()}>
        {rows.map((row, i) => {
          prepareRow(row);
          return (
            <tr key={`tbody-tr-${i}`} {...row.getRowProps()}>
              {row.cells.map((cell, j) => {
                let additionalProps = {};
                if (cell.column.id == "color" && cell.value) {
                  return (
                    <td
                      key={`thead-td-${i}-${j}`}
                      {...cell.getCellProps()}
                      {...additionalProps}
                    >
                      <div
                        style={{
                          backgroundColor: cell.value,
                          width: "45px",
                          height: "45px"
                        }}
                      >
                        {cell.render("Cell")}
                      </div>
                    </td>
                  );
                }
                return (
                  <td
                    key={`thead-td-${i}-${j}`}
                    {...cell.getCellProps()}
                    {...additionalProps}
                  >
                    {cell.render("Cell")}
                  </td>
                );
              })}
              <ActionsCell {...row.original} id={row.original.id} />
            </tr>
          );
        })}
      </tbody>
      <tfoot>
        {footerGroups.map((group, i) => (
          <tr
            key={`tfoot-tr-${i}`}
            className="align-top"
            {...group.getFooterGroupProps()}
          >
            {group.headers.map((column, j) => (
              <td key={`tfoot-td-${i}-${j}`} {...column.getFooterProps()}>
                {column.render("Footer")}
              </td>
            ))}
            <td></td>
          </tr>
        ))}
      </tfoot>
    </table>
  </div>
);
