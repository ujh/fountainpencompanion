import React, { useMemo } from "react";
import { useTable, useSortBy, useGlobalFilter } from "react-table";
import _ from "lodash";
import { fuzzyMatch } from "./match";
import { Actions } from "./Actions";
import { Counter } from "./Counter";
import { InkWithLink } from "./InkWithLink";
import { Table } from "./Table";
import { booleanSort, colorSort } from "./sort";

export const CollectedInksTable = ({ data, archive }) => {
  const columns = useMemo(
    () => [
      {
        accessor: "private",
        Cell: ({ cell: { value } }) => {
          if (value) {
            return (
              <i
                title="Private, hidden from your profile"
                className="fa fa-lock"
              />
            );
          } else {
            return (
              <i
                title="Publicly visible on your profile"
                className="fa fa-unlock"
              />
            );
          }
        }
      },
      {
        Header: "Brand",
        accessor: "brand_name",
        Footer: (info) => {
          const count = useMemo(() => {
            return _.uniqBy(info.rows, (row) => row.values["brand_name"])
              .length;
          }, [info.rows]);
          return <span>{count} brands</span>;
        }
      },
      {
        Header: "Line",
        accessor: "line_name"
      },
      {
        Header: "Name",
        accessor: "ink_name",
        Cell: InkWithLink,
        Footer: (info) => {
          return <span>{info.rows.length} inks</span>;
        }
      },
      {
        Header: "Maker",
        accessor: "maker"
      },
      {
        Header: "Type",
        accessor: "kind",
        Footer: (info) => {
          const counters = useMemo(() => {
            return _.countBy(info.rows, (row) => row.values["kind"]);
          }, [info.rows]);
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
        Header: "Color",
        accessor: "color",
        Cell: () => "",
        sortType: colorSort
      },
      {
        Header: "Swabbed",
        accessor: "swabbed",
        Cell: ({ cell: { value } }) => {
          if (value) {
            return <i className="fa fa-check" />;
          } else {
            return <i className="fa fa-times" />;
          }
        },
        sortType: booleanSort
      },
      {
        Header: "Used",
        accessor: "used",
        Cell: ({ cell: { value } }) => {
          if (value) {
            return <i className="fa fa-check" />;
          } else {
            return <i className="fa fa-times" />;
          }
        },
        sortType: booleanSort
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
        Header: "Comment",
        accessor: "comment"
      },
      {
        Header: "Private Comment",
        accessor: "private_comment"
      },
      {
        Header: "Tags",
        accessor: "tags",
        Cell: ({ cell: { value } }) => {
          if (!value.length) return null;
          return (
            <ul className="tags">
              {value.map((tag) => (
                <li key={tag.id} className="tag badge text-bg-secondary">
                  {tag.name}
                </li>
              ))}
            </ul>
          );
        }
      }
    ],
    []
  );
  const hiddenColumns = useMemo(() => {
    let hidden_columns = [
      "private_comment",
      "comment",
      "maker",
      "line_name",
      "kind",
      "daily_usage"
    ].filter((n) => !data.some((e) => e[n]));
    if (data.every((e) => e.tags.length == 0)) hidden_columns.push("tags");
    return hidden_columns;
  }, [data]);
  const {
    getTableProps,
    getTableBodyProps,
    headerGroups,
    footerGroups,
    rows,
    prepareRow,
    state,
    preGlobalFilteredRows,
    setGlobalFilter
  } = useTable(
    {
      columns,
      data,
      initialState: {
        hiddenColumns
      },
      filterTypes: {
        fuzzyText: fuzzyMatch
      },
      globalFilter: "fuzzyText"
    },
    useGlobalFilter,
    useSortBy
  );
  return (
    <div>
      <Actions
        archive={archive}
        preGlobalFilteredRows={preGlobalFilteredRows}
        globalFilter={state.globalFilter}
        setGlobalFilter={setGlobalFilter}
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
