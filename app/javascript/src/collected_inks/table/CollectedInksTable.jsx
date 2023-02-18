import React, { useCallback, useEffect, useMemo, useState } from "react";
import { useTable, useSortBy, useGlobalFilter } from "react-table";
import _ from "lodash";
import * as storage from "../../localStorage";
import { Actions } from "../components";
import { fuzzyMatch } from "./match";
import { Counter } from "./Counter";
import { InkWithLink } from "./InkWithLink";
import { Table } from "./Table";
import { booleanSort, colorSort } from "./sort";

export const storageKeyHiddenFields = "fpc-collected-inks-table-hidden-fields";

export const CollectedInksTable = ({ data, archive, onLayoutChange }) => {
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

  const [hiddenFields, setHiddenFields] = useState([]);

  const getDefaultHiddenFields = useCallback(() => {
    let hideIfNoInksWithValue = [
      "private",
      "private_comment",
      "comment",
      "maker",
      "line_name",
      "kind",
      "daily_usage"
    ].filter((n) => !data.some((e) => e[n]));

    if (data.every((e) => e.tags.length == 0)) {
      hideIfNoInksWithValue.push("tags");
    }
    return hideIfNoInksWithValue;
  }, [data]);

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
      data,
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
