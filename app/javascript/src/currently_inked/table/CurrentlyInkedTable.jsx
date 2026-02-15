import React, { useMemo, useEffect } from "react";
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  flexRender
} from "@tanstack/react-table";
import _ from "lodash";
import { useHiddenFields } from "../../useHiddenFields";
import { Actions } from "../components/Actions";
import { fuzzyMatch } from "./match";
import { Table } from "../../components/Table";
import { colorSort } from "./sort";
import { ActionsCell } from "./ActionsCell";
import { RelativeDate } from "../../components/RelativeDate";

export const storageKeyHiddenFields = "fpc-currently-inked-table-hidden-fields";

export const CurrentlyInkedTable = ({ currentlyInked, onLayoutChange }) => {
  const columns = useMemo(
    () => [
      {
        header: "Pen",
        accessorKey: "pen_name",
        cell: ({ getValue, row }) => {
          const value = getValue();
          const model_variant_id = row.original.collected_pen.model_variant_id;
          if (model_variant_id) {
            return (
              <span>
                {value}{" "}
                <a href={`/pen_variants/${model_variant_id}`}>
                  <i className="fa fa-external-link"></i>
                </a>
              </span>
            );
          } else {
            return <span>{value}</span>;
          }
        },
        footer: ({ table }) => {
          return <span>{table.getFilteredRowModel().rows.length} pens</span>;
        }
      },
      {
        header: "Color",
        accessorKey: "collected_ink.color",
        sortingFn: colorSort,
        cell: ({ getValue }) => {
          const value = getValue();
          return <div style={{ backgroundColor: value, width: "45px", height: "45px" }}></div>;
        }
      },
      {
        header: "Ink",
        accessorKey: "ink_name",
        cell: ({ getValue, row }) => {
          const value = getValue();
          const micro_cluster = row.original.collected_ink.micro_cluster;
          if (!micro_cluster) return value;

          const macro_cluster = micro_cluster.macro_cluster;
          if (!macro_cluster) return value;

          const public_id = macro_cluster.id;
          const link = `/inks/${public_id}`;
          return (
            <>
              {value}{" "}
              <a href={link}>
                <i className="fa fa-external-link"></i>
              </a>
            </>
          );
        },
        footer: ({ table }) => {
          const rows = table.getFilteredRowModel().rows;
          const ink_names = rows.map((row) => {
            const { brand_name, line_name, ink_name } = row.original.collected_ink;
            return [brand_name, line_name, ink_name].join();
          });
          const uniqueInkNames = _.uniq(ink_names);
          const count = uniqueInkNames.length;
          return <span>{count} inks</span>;
        }
      },
      {
        header: "Date Inked",
        accessorKey: "inked_on",
        cell: ({ getValue }) => <RelativeDate date={getValue()} relativeAsDefault={false} />
      },
      {
        header: "Last Used",
        accessorKey: "last_used_on",
        sortDescFirst: true,
        cell: ({ getValue }) => <RelativeDate date={getValue()} />
      },
      {
        header: "Usage",
        accessorKey: "daily_usage"
      },
      {
        header: "Comment",
        accessorKey: "comment"
      },
      {
        header: "Actions",
        meta: { className: "fpc-actions-column" },
        cell: ({ row }) => {
          return <ActionsCell {...row.original} id={row.original.id} />;
        }
      }
    ],
    []
  );

  const defaultHiddenFields = useMemo(() => {
    let hideIfNoneWithValue = ["comment"].filter((n) => !currentlyInked.some((e) => e[n]));
    return hideIfNoneWithValue;
  }, [currentlyInked]);

  const { hiddenFields, onHiddenFieldsChange } = useHiddenFields(
    storageKeyHiddenFields,
    defaultHiddenFields
  );

  const table = useReactTable({
    columns,
    data: currentlyInked,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    state: {
      columnVisibility: hiddenFields.reduce((acc, field) => ({ ...acc, [field]: false }), {})
    },
    onColumnVisibilityChange: (updater) => {
      if (typeof updater === "function") {
        const newVisibility = updater(
          hiddenFields.reduce((acc, field) => ({ ...acc, [field]: false }), {})
        );
        const newHiddenFields = Object.keys(newVisibility).filter((key) => !newVisibility[key]);
        onHiddenFieldsChange(newHiddenFields);
      }
    },
    globalFilterFn: fuzzyMatch,
    enableGlobalFilter: true
  });

  const setGlobalFilter = table.setGlobalFilter;
  const preGlobalFilteredRows = table.getPreFilteredRowModel().rows;

  useEffect(() => {
    const visibility = hiddenFields.reduce((acc, field) => ({ ...acc, [field]: false }), {});
    table.setColumnVisibility(visibility);
  }, [hiddenFields, table]);

  // Extract table props for backward compatibility with Table component
  const getTableProps = () => ({ role: "table" });
  const getTableBodyProps = () => ({ role: "rowgroup" });

  // Add backward compatibility methods to v8 objects
  const headerGroups = table.getHeaderGroups().map((headerGroup) => ({
    ...headerGroup,
    getHeaderGroupProps: () => ({ role: "row" }),
    headers: headerGroup.headers.map((header) => ({
      ...header,
      getHeaderProps: (userProps = {}) => {
        const metaClass = header.column.columnDef?.meta?.className;
        const mergedClassName = [userProps.className, metaClass].filter(Boolean).join(" ");
        const baseStyle =
          metaClass === "fpc-actions-column" ? { width: "1%", whiteSpace: "nowrap" } : {};
        const sortableStyle = header.column.getCanSort()
          ? { cursor: "pointer", userSelect: "none", WebkitUserSelect: "none" }
          : {};
        const style = { ...baseStyle, ...sortableStyle };
        const title = header.column.getCanSort() ? "Toggle SortBy" : undefined;
        return {
          ...userProps,
          className: mergedClassName,
          style,
          role: "columnheader",
          colSpan: 1,
          title
        };
      },
      getSortByToggleProps: () => ({
        onClick: header.column.getToggleSortingHandler?.()
      }),
      getIsSorted: () => header.column.getIsSorted?.(),
      isSorted: header.column.getIsSorted?.() ? true : false,
      isSortedDesc: header.column.getIsSorted?.() === "desc",
      render: (type) => {
        if (type === "Header") {
          return flexRender(header.column.columnDef.header, header.getContext());
        }
        return null;
      }
    }))
  }));

  const footerGroups = table.getFooterGroups().map((footerGroup) => ({
    ...footerGroup,
    getFooterGroupProps: () => ({ role: "row" }),
    headers: footerGroup.headers.map((header) => ({
      ...header,
      getFooterProps: () => {
        const metaClass = header.column.columnDef?.meta?.className;
        const style =
          metaClass === "fpc-actions-column" ? { width: "1%", whiteSpace: "nowrap" } : undefined;
        return metaClass
          ? { className: metaClass, style, role: "columnheader", colSpan: 1 }
          : { style, role: "columnheader", colSpan: 1 };
      },
      render: (type) => {
        if (type === "Footer") {
          return flexRender(header.column.columnDef.footer, header.getContext());
        }
        return null;
      }
    }))
  }));

  const rows = table.getRowModel().rows.map((row) => ({
    ...row,
    getRowProps: () => ({ role: "row" }),
    cells: row.getVisibleCells().map((cell) => ({
      ...cell,
      getCellProps: () => {
        const metaClass = cell.column.columnDef?.meta?.className;
        const style =
          metaClass === "fpc-actions-column" ? { width: "1%", whiteSpace: "nowrap" } : undefined;
        return metaClass
          ? { className: metaClass, style, role: "cell", colSpan: 1 }
          : { style, role: "cell", colSpan: 1 };
      }
    }))
  }));

  const prepareRow = () => {};

  return (
    <div className="fpc-currently-inked-table">
      <Actions
        activeLayout="table"
        numberOfEntries={preGlobalFilteredRows.length}
        onFilterChange={setGlobalFilter}
        onLayoutChange={onLayoutChange}
        hiddenFields={hiddenFields}
        onHiddenFieldsChange={onHiddenFieldsChange}
      />
      <Table
        getTableProps={getTableProps}
        headerGroups={headerGroups}
        getTableBodyProps={getTableBodyProps}
        rows={rows}
        prepareRow={prepareRow}
        footerGroups={footerGroups}
      />
    </div>
  );
};
