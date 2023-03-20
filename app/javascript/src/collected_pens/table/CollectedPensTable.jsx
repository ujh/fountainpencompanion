import React, { useMemo, useState, useEffect, useCallback } from "react";
import { useTable, useSortBy, useGlobalFilter } from "react-table";
import _ from "lodash";
import * as storage from "../../localStorage";
import { Table } from "../../components/Table";
import { Actions } from "../components/Actions";
import { ActionsCell } from "./ActionsCell";
import { fuzzyMatch } from "./match";

export const storageKeyHiddenFields = "fpc-collected-pens-table-hidden-fields";

export const CollectedPensTable = ({ pens, onLayoutChange }) => {
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

  const [hiddenFields, setHiddenFields] = useState([]);

  const getDefaultHiddenFields = useCallback(() => {
    let hideIfNoneWithValue = [
      "nib",
      "color",
      "comment",
      "usage",
      "daily_usage"
    ].filter((n) => !pens.some((e) => e[n]));
    return hideIfNoneWithValue;
  }, [pens]);

  useEffect(() => {
    const fromLocalStorage = JSON.parse(
      storage.getItem(storageKeyHiddenFields)
    );
    if (fromLocalStorage) {
      setHiddenFields(fromLocalStorage);
      return;
    }

    setHiddenFields(getDefaultHiddenFields());
  }, [getDefaultHiddenFields, setHiddenFields]);

  const onHiddenFieldsChange = useCallback(
    (nextHiddenFields) => {
      if (nextHiddenFields === null) {
        storage.removeItem(storageKeyHiddenFields);

        setHiddenFields(getDefaultHiddenFields());

        return;
      }

      setHiddenFields(nextHiddenFields);
      storage.setItem(storageKeyHiddenFields, JSON.stringify(nextHiddenFields));
    },
    [setHiddenFields, getDefaultHiddenFields]
  );

  const {
    getTableProps,
    getTableBodyProps,
    headerGroups,
    footerGroups,
    rows,
    prepareRow,
    preGlobalFilteredRows,
    setGlobalFilter,
    setHiddenColumns
  } = useTable(
    {
      columns,
      data: pens,
      initialState: {
        hiddenColumns: hiddenFields
      },
      filterTypes: {
        fuzzyText: fuzzyMatch
      },
      globalFilter: "fuzzyText"
    },
    useGlobalFilter,
    useSortBy
  );

  useEffect(() => {
    setHiddenColumns(hiddenFields);
  }, [hiddenFields, setHiddenColumns]);

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
