import React, { useEffect, useMemo } from "react";
import { useTable, useSortBy, useGlobalFilter } from "react-table";
import _ from "lodash";
import { RelativeDate } from "../../components/RelativeDate";
import { useHiddenFields } from "../../useHiddenFields";
import { Actions } from "../components";
import { fuzzyMatch } from "./match";
import { Counter } from "./Counter";
import { InkWithLink } from "./InkWithLink";
import { Table } from "../../components/Table";
import { booleanSort, colorSort } from "./sort";
import { ActionsCell } from "./ActionsCell";

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
        Cell: ({ cell: { value } }) => (
          <div
            style={{
              backgroundColor: value,
              width: "45px",
              height: "45px"
            }}
          ></div>
        ),
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
        Header: "Last Usage",
        accessor: "last_used_on",
        sortDescFirst: true,
        Cell: ({ cell: { value } }) => <RelativeDate date={value} />
      },
      {
        Header: "Added On",
        accessor: "created_at",
        Cell: ({ cell: { value } }) => (
          <RelativeDate date={value} relativeAsDefault={false} />
        )
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
        Cell: ({
          cell: {
            value,
            row: {
              original: { cluster_tags, ink_id }
            }
          }
        }) => {
          if (!value.length && !cluster_tags.length) return null;
          const extraClusterTags = _.difference(
            cluster_tags,
            value.map((t) => t.name)
          );
          const extraToDisplay = Math.max(0, 5 - value.length);
          return (
            <ul className="tags">
              {value.map((tag) => (
                <li key={tag.id} className="tag badge text-bg-secondary">
                  {tag.name}
                </li>
              ))}
              {extraClusterTags.slice(0, extraToDisplay).map((tag) => (
                <li
                  key={tag}
                  className="tag badge text-bg-secondary cluster-tag"
                >
                  {tag}
                </li>
              ))}
              {extraClusterTags.length > extraToDisplay && (
                <li className="tag badge text-bg-secondary cluster-tag">
                  <a href={`/inks/${ink_id}`}>...</a>
                </li>
              )}
            </ul>
          );
        }
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
    return hideIfNoInksWithValue;
  }, [data]);

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
