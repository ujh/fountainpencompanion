import React, { useMemo } from "react";
import { useTable, useSortBy } from "react-table";
import _ from "lodash";

import { Table } from "../components/Table";
import { Actions } from "./Actions";
import { ActionsCell } from "./ActionsCell";

export const CollectedPensTable = ({ pens }) => {
  const columns = useMemo(
    () => [
      {
        Header: "Brand",
        accessor: "brand",
        Footer: (info) => {
          const count = useMemo(() => {
            return _.uniqBy(info.rows, (row) => row.values["brand"]).length;
          }, [info.rows]);
          return <span>{count} brands</span>;
        }
      },
      {
        Header: "Model",
        accessor: "model",
        Footer: (info) => {
          return <span>{info.rows.length} pens</span>;
        }
      },
      {
        Header: "Nib",
        accessor: "nib"
      },
      {
        Header: "Color",
        accessor: "color"
      },
      {
        Header: "Comment",
        accessor: "comment"
      },
      {
        Header: "Usage",
        accessor: "usage",
        sortDescFirst: true
      },
      {
        Header: "Daily Usage",
        accessor: "daily_usage",
        sortDescFirst: true
      },
      {
        Header: "Actions",
        Cell: ({ cell: { row } }) => {
          return <ActionsCell {...row.original} id={row.original.id} />;
        }
      }
    ],
    []
  );

  const {
    getTableProps,
    getTableBodyProps,
    headerGroups,
    footerGroups,
    rows,
    prepareRow
  } = useTable(
    {
      columns,
      data: pens
    },
    useSortBy
  );

  return (
    <div>
      <Actions />
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
