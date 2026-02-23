import React, { useEffect, useMemo } from "react";
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  flexRender
} from "@tanstack/react-table";
import _ from "lodash";
import { RelativeDate } from "../../components/RelativeDate";
import { useHiddenFields } from "../../useHiddenFields";
import { Actions } from "../components";
import { fuzzyMatch } from "./match";
import { Counter } from "./Counter";
import { InkWithLink } from "./InkWithLink";
import { Table } from "../../components/Table";
import { booleanSort, colorSort, dateSort } from "./sort";
import { ActionsCell } from "./ActionsCell";

export const storageKeyHiddenFields = "fpc-collected-inks-table-hidden-fields";

function fixedEncodeURIComponent(str) {
  return encodeURIComponent(str).replace(/[!'()*]/g, function (c) {
    return "%" + c.charCodeAt(0).toString(16);
  });
}

export const CollectedInksTable = ({ data, archive, onLayoutChange }) => {
  const columns = useMemo(
    () => [
      {
        accessorKey: "private",
        cell: ({ getValue }) => {
          const value = getValue();
          if (value) {
            return <i title="Private, hidden from your profile" className="fa fa-lock" />;
          } else {
            return <i title="Publicly visible on your profile" className="fa fa-unlock" />;
          }
        }
      },
      {
        header: "Brand",
        accessorKey: "brand_name",
        footer: ({ table }) => {
          const rows = table.getFilteredRowModel().rows;
          const count = _.uniqBy(rows, (row) => row.original.brand_name).length;
          return <span>{count} brands</span>;
        }
      },
      {
        header: "Line",
        accessorKey: "line_name"
      },
      {
        header: "Name",
        accessorKey: "ink_name",
        cell: ({ getValue, row }) => <InkWithLink value={getValue()} row={row} />,
        footer: ({ table }) => {
          return <span>{table.getFilteredRowModel().rows.length} inks</span>;
        }
      },
      {
        header: "Maker",
        accessorKey: "maker"
      },
      {
        header: "Type",
        accessorKey: "kind",
        footer: ({ table }) => {
          const rows = table.getFilteredRowModel().rows;
          const counters = _.countBy(rows, (row) => row.original.kind);
          return (
            <span>
              <Counter data={counters} field="bottle" />
              <Counter data={counters} field="sample" />
              <Counter data={counters} field="cartridge" />
              <Counter data={counters} field="swab" />
            </span>
          );
        }
      },
      {
        header: "Color",
        accessorKey: "color",
        cell: ({ getValue }) => {
          const value = getValue();
          return (
            <div
              style={{
                backgroundColor: value,
                width: "45px",
                height: "45px"
              }}
            ></div>
          );
        },
        sortingFn: colorSort
      },
      {
        header: "Swabbed",
        accessorKey: "swabbed",
        cell: ({ getValue }) => {
          const value = getValue();
          if (value) {
            return <i className="fa fa-check" />;
          } else {
            return <i className="fa fa-times" />;
          }
        },
        sortingFn: booleanSort
      },
      {
        header: "Used",
        accessorKey: "used",
        cell: ({ getValue }) => {
          const value = getValue();
          if (value) {
            return <i className="fa fa-check" />;
          } else {
            return <i className="fa fa-times" />;
          }
        },
        sortingFn: booleanSort
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
        sortingFn: dateSort,
        cell: ({ getValue }) => <RelativeDate date={getValue()} />
      },
      {
        header: "Added On",
        accessorKey: "created_at",
        cell: ({ getValue }) => <RelativeDate date={getValue()} relativeAsDefault={false} />
      },
      {
        header: "Comment",
        accessorKey: "comment"
      },
      {
        header: "Private Comment",
        accessorKey: "private_comment"
      },
      {
        header: "Tags",
        accessorKey: "tags",
        cell: ({ getValue }) => {
          const value = getValue();
          if (!value.length) return null;
          return (
            <ul className="tags">
              {value.map((tag) => (
                <li key={tag.id} className="tag badge text-bg-secondary">
                  <a href={`/inks?tag=${fixedEncodeURIComponent(tag.name)}`}>{tag.name}</a>
                </li>
              ))}
            </ul>
          );
        }
      },
      {
        header: "Cluster Tags",
        accessorKey: "cluster_tags",
        cell: ({ getValue, row }) => {
          const value = getValue();
          const tags = row.original.tags || [];
          if (!value.length) return null;
          const clusterOnlyTags = _.difference(
            value,
            tags.map((t) => t.name)
          );
          return (
            <ul className="tags">
              {clusterOnlyTags.map((tag) => (
                <li key={tag} className="tag badge text-bg-secondary cluster-tag">
                  <a href={`/inks?tag=${fixedEncodeURIComponent(tag)}`}>{tag}</a>
                </li>
              ))}
            </ul>
          );
        }
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
    let hideIfNoInksWithValue = [
      "private",
      "private_comment",
      "comment",
      "maker",
      "line_name",
      "kind",
      "daily_usage",
      "last_used_on"
    ].filter((n) => !data.some((e) => e[n]));

    if (data.every((e) => e.tags.length == 0)) {
      hideIfNoInksWithValue.push("tags");
    }
    if (data.every((e) => e.cluster_tags.length == 0)) {
      hideIfNoInksWithValue.push("cluster_tags");
    }
    return hideIfNoInksWithValue;
  }, [data]);

  const { hiddenFields, onHiddenFieldsChange } = useHiddenFields(
    storageKeyHiddenFields,
    defaultHiddenFields
  );

  const table = useReactTable({
    columns,
    data,
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
        archive={archive}
        activeLayout="table"
        numberOfInks={preGlobalFilteredRows.length}
        onFilterChange={setGlobalFilter}
        onLayoutChange={onLayoutChange}
        hiddenFields={hiddenFields}
        onHiddenFieldsChange={onHiddenFieldsChange}
      />
      <Table
        hiddenFields={hiddenFields}
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
