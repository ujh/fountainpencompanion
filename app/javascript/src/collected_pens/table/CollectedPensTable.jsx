import React, { useMemo, useEffect } from "react";
import { useTable, useSortBy, useGlobalFilter } from "react-table";
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
        Cell: ({
          cell: {
            value,
            row: {
              original: { model_variant_id }
            }
          }
        }) => {
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
        Header: "Material",
        accessor: "material"
      },
      {
        Header: "Trim Color",
        accessor: "trim_color"
      },
      {
        Header: "Filling System",
        accessor: "filling_system"
      },
      {
        Header: "Price",
        accessor: "price"
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
        Header: "Last Usage",
        accessor: "last_used_on",
        sortDescFirst: true,
        Cell: ({ cell: { value } }) => <RelativeDate date={value} />
      },
      {
        Header: "Added On",
        accessor: "created_at",
        Cell: ({ cell: { value } }) => <RelativeDate date={value} relativeAsDefault={false} />
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
