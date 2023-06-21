import React, { useMemo, useEffect } from "react";
import { useTable, useSortBy, useGlobalFilter } from "react-table";
import _ from "lodash";
import { useHiddenFields } from "../../useHiddenFields";
import { Actions } from "../components/Actions";
import { fuzzyMatch } from "./match";
import { Table } from "../../components/Table";
import { colorSort } from "./sort";
import { ActionsCell } from "./ActionsCell";

export const storageKeyHiddenFields = "fpc-currently-inked-table-hidden-fields";

export const CurrentlyInkedTable = ({ currentlyInked, onLayoutChange }) => {
  const columns = useMemo(
    () => [
      {
        Header: "Pen",
        accessor: "pen_name",
        Footer: ({ rows }) => {
          return <span>{rows.length} pens</span>;
        }
      },
      {
        Header: "Color",
        accessor: "collected_ink.color",
        sortType: colorSort,
        Cell: ({ cell: { value } }) => {
          return (
            <div
              style={{ backgroundColor: value, width: "45px", height: "45px" }}
            ></div>
          );
        }
      },
      {
        Header: "Ink",
        accessor: "ink_name",
        Cell: ({ cell }) => {
          const micro_cluster = cell.row.original.collected_ink.micro_cluster;
          if (!micro_cluster) return cell.value;

          const macro_cluster = micro_cluster.macro_cluster;
          if (!macro_cluster) return cell.value;

          const public_id = macro_cluster.id;
          const link = `/inks/${public_id}`;
          return (
            <>
              {cell.value}{" "}
              <a href={link}>
                <i className="fa fa-external-link"></i>
              </a>
            </>
          );
        },
        Footer: ({ rows }) => {
          const count = useMemo(() => {
            const ink_names = rows.map(
              ({
                original: {
                  collected_ink: { brand_name, line_name, ink_name }
                }
              }) => [brand_name, line_name, ink_name].join()
            );
            const uniqueInkNames = _.uniq(ink_names);
            return uniqueInkNames.length;
          }, [rows]);
          return <span>{count} inks</span>;
        }
      },
      {
        Header: "Date Inked",
        accessor: "inked_on"
      },
      {
        Header: "Last Used",
        accessor: "last_used_on",
        sortDescFirst: true
      },
      {
        Header: "Comment",
        accessor: "comment"
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

  const defaultHiddenFields = useMemo(() => {
    let hideIfNoneWithValue = ["comment"].filter(
      (n) => !currentlyInked.some((e) => e[n])
    );
    return hideIfNoneWithValue;
  }, [currentlyInked]);

  const { hiddenFields, onHiddenFieldsChange } = useHiddenFields(
    storageKeyHiddenFields,
    defaultHiddenFields
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
      data: currentlyInked,
      initialState: {
        hiddenColumns: hiddenFields,
        sortBy: [{ id: "pen_name" }]
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
