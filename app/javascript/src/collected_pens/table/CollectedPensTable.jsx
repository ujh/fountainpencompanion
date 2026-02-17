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
import { Table } from "../../components/Table";
import { Actions } from "../components/Actions";
import { ActionsCell } from "./ActionsCell";
import { fuzzyMatch } from "./match";
import { RelativeDate } from "../../components/RelativeDate";

export const storageKeyHiddenFields = "fpc-collected-pens-table-hidden-fields";

export const CollectedPensTable = ({ pens, onLayoutChange }) => {
  const columns = useMemo(
    () => [
      {
        header: "Brand",
        accessorKey: "brand",
        footer: ({ table }) => {
          const rows = table.getFilteredRowModel().rows;
          const uniqueBrands = _.uniqBy(rows, (row) => row.original.brand).length;
          return <span>{uniqueBrands} brands</span>;
        }
      },
      {
        header: "Model",
        accessorKey: "model",
        cell: ({ getValue, row }) => {
          const value = getValue();
          const model_variant_id = row.original.model_variant_id;
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
        header: "Nib",
        accessorKey: "nib"
      },
      {
        header: "Color",
        accessorKey: "color"
      },
      {
        header: "Material",
        accessorKey: "material"
      },
      {
        header: "Trim Color",
        accessorKey: "trim_color"
      },
      {
        header: "Filling System",
        accessorKey: "filling_system"
      },
      {
        header: "Price",
        accessorKey: "price"
      },
      {
        header: "Comment",
        accessorKey: "comment"
      },
      {
        header: "Usage",
        accessorKey: "usage",
        sortDescFirst: true
      },
      {
        header: "Daily Usage",
        accessorKey: "daily_usage",
        sortDescFirst: true
      },
      {
        header: "Last Usage",
        accessorKey: "last_used_on",
        sortDescFirst: true,
        cell: ({ getValue }) => <RelativeDate date={getValue()} />
      },
      {
        header: "Added On",
        accessorKey: "created_at",
        cell: ({ getValue }) => <RelativeDate date={getValue()} relativeAsDefault={false} />
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
    let hideIfNoneWithValue = [
      "nib",
      "color",
      "comment",
      "usage",
      "daily_usage",
      "last_used_on",
      "material",
      "price",
      "trim_color",
      "filling_system"
    ].filter((n) => !pens.some((e) => e[n]));
    return hideIfNoneWithValue;
  }, [pens]);

  const { hiddenFields, onHiddenFieldsChange } = useHiddenFields(
    storageKeyHiddenFields,
    defaultHiddenFields
  );

  const table = useReactTable({
    columns,
    data: pens,
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
    <div>
      <Actions
        activeLayout="table"
        numberOfPens={preGlobalFilteredRows.length}
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
