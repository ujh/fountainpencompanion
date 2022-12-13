import React, { useState, useEffect, useMemo } from "react";
import { createRoot } from "react-dom/client";
import { useTable, useSortBy, useGlobalFilter } from "react-table";
import { matchSorter } from "match-sorter";
import _ from "lodash";
import { getRequest } from "src/fetch";
import { colorSort } from "../color-sorting";
import Jsona from "jsona";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll("#collected-inks .app");
  Array.from(elements).forEach((el) => {
    const root = createRoot(el);
    root.render(
      <CollectedInks archive={el.getAttribute("data-archive") == "true"} />
    );
  });
});

const CollectedInks = ({ archive }) => {
  const [inks, setInks] = useState();
  useEffect(() => {
    getRequest("/collected_inks.json")
      .then((response) => response.json())
      .then((json) => {
        const formatter = new Jsona();
        return formatter.deserialize(json);
      })
      .then((ink_data) => setInks(ink_data));
  }, []);
  const visibleInks = useMemo(
    () => (inks || []).filter((i) => i.archived == archive),
    [inks]
  );
  if (inks) {
    return <CollectedInksTable data={visibleInks} archive={archive} />;
  } else {
    return (
      <div className="loader">
        <i className="fa fa-spin fa-refresh" />
      </div>
    );
  }
};

const renderInkWithLink = ({
  cell: {
    value,
    row: {
      original: { ink_id },
    },
  },
}) => {
  if (ink_id) {
    return (
      <>
        {value}
        <a href={`/inks/${ink_id}`}>
          &nbsp;
          <i className="fa fa-external-link" />
        </a>
      </>
    );
  }
  return value;
};

const CollectedInksTable = ({ data, archive }) => {
  const columns = useMemo(
    () => [
      {
        accessor: "private",
        Cell: ({ cell: { value } }) => {
          if (value) {
            return <i className="fa fa-lock" />;
          } else {
            return <i className="fa fa-unlock" />;
          }
        },
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
        },
      },
      {
        Header: "Line",
        accessor: "line_name",
      },
      {
        Header: "Name",
        accessor: "ink_name",
        Cell: renderInkWithLink,
        Footer: (info) => {
          return <span>{info.rows.length} inks</span>;
        },
      },
      {
        Header: "Maker",
        accessor: "maker",
      },
      {
        Header: "Type",
        accessor: "kind",
        Footer: (info) => {
          const counters = useMemo(() => {
            return _.countBy(info.rows, (row) => row.values["kind"]);
          });
          return (
            <span>
              <Counter data={counters} field="bottle" />
              <Counter data={counters} field="sample" />
              <Counter data={counters} field="cartridge" />
              <Counter data={counters} field="swab" />
            </span>
          );
        },
      },
      {
        Header: "Color",
        accessor: "color",
        Cell: () => "",
        sortType: sortByColor,
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
        sortType: booleanSort,
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
        sortType: booleanSort,
      },
      {
        Header: "Usage",
        accessor: "usage",
        sortDescFirst: true,
      },
      {
        Header: "Daily Usage",
        accessor: "daily_usage",
        sortDescFirst: true,
      },
      {
        Header: "Comment",
        accessor: "comment",
      },
      {
        Header: "Private Comment",
        accessor: "private_comment",
      },
      {
        Header: "Tags",
        accessor: "tags",
        Cell: ({ cell: { value } }) => {
          if (!value.length) return null;
          return (
            <ul className="tags">
              {value.map((tag) => (
                <li key={tag.id} className="tag">
                  {tag.name}
                </li>
              ))}
            </ul>
          );
        },
      },
    ],
    [data]
  );
  const hiddenColumns = useMemo(() => {
    let hidden_columns = [
      "private_comment",
      "comment",
      "maker",
      "line_name",
      "kind",
      "daily_usage",
    ].filter((n) => !data.some((e) => e[n]));
    if (data.every((e) => e.tags.length == 0)) hidden_columns.push("tags");
    return hidden_columns;
  }, []);
  const {
    getTableProps,
    getTableBodyProps,
    headerGroups,
    footerGroups,
    rows,
    prepareRow,
    state,
    preGlobalFilteredRows,
    setGlobalFilter,
  } = useTable(
    {
      columns,
      data,
      initialState: {
        hiddenColumns,
      },
      filterTypes: {
        fuzzyText: fuzzyTextFilterFn,
      },
      globalFilter: "fuzzyText",
    },
    useGlobalFilter,
    useSortBy
  );
  return (
    <div>
      {!archive && (
        <a className="add-button" href="/collected_inks/new">
          <i className="fa fa-plus" />
        </a>
      )}
      <Buttons
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
      <Buttons
        archive={archive}
        preGlobalFilteredRows={preGlobalFilteredRows}
        globalFilter={state.globalFilter}
        setGlobalFilter={setGlobalFilter}
      />
    </div>
  );
};

const Counter = ({ data, field }) => {
  const value = data[field];
  if (!value) return null;

  return (
    <>
      <span className="counter">
        {value}x {field}
      </span>
      <br />
    </>
  );
};

const Table = ({
  getTableProps,
  headerGroups,
  footerGroups,
  getTableBodyProps,
  rows,
  prepareRow,
}) => (
  <div className="table-wrapper">
    <table {...getTableProps()} className="table table-striped table-sm">
      <thead>
        {headerGroups.map((headerGroup) => (
          <tr {...headerGroup.getHeaderGroupProps()}>
            {headerGroup.headers.map((column) => (
              <th {...column.getHeaderProps(column.getSortByToggleProps())}>
                {column.render("Header")}
                <span>
                  &nbsp;
                  {column.isSorted ? (
                    <i
                      className={`fa fa-arrow-${
                        column.isSortedDesc ? "down" : "up"
                      }`}
                    />
                  ) : (
                    ""
                  )}
                </span>
              </th>
            ))}
            <th>Actions</th>
          </tr>
        ))}
      </thead>
      <tbody {...getTableBodyProps()}>
        {rows.map((row, i) => {
          prepareRow(row);
          return (
            <tr {...row.getRowProps()}>
              {row.cells.map((cell) => {
                let additionalProps = {};
                if (cell.column.id == "color" && cell.value) {
                  additionalProps = {
                    style: { backgroundColor: cell.value, width: "30px" },
                  };
                }
                return (
                  <td {...cell.getCellProps()} {...additionalProps}>
                    {cell.render("Cell")}
                  </td>
                );
              })}
              <ActionsCell {...row.original} id={row.original.id} />
            </tr>
          );
        })}
      </tbody>
      <tfoot>
        {footerGroups.map((group) => (
          <tr {...group.getFooterGroupProps()}>
            {group.headers.map((column) => (
              <td {...column.getFooterProps()}>{column.render("Footer")}</td>
            ))}
            <td></td>
          </tr>
        ))}
      </tfoot>
    </table>
  </div>
);

const Buttons = ({
  archive,
  preGlobalFilteredRows,
  setGlobalFilter,
  globalFilter,
}) => {
  return (
    <div className="row buttons">
      {!archive && (
        <>
          <div className="col-sm-12 col-md-2 col-lg-2">
            <a className="btn btn-primary" href="/collected_inks/new">
              Add Ink
            </a>
          </div>
          <div className="col-sm-12 col-md-2 col-lg-2">
            <a
              className="btn btn-secondary"
              href="/collected_inks?search[archive]=true"
            >
              Archive
            </a>
          </div>
        </>
      )}
      <div className={archive ? "col-sm-12" : "col-sm-12 col-md-8 col-lg-8"}>
        <div className="search">
          <input
            value={globalFilter || ""}
            onChange={(e) => {
              setGlobalFilter(e.target.value || undefined); // Set undefined to remove the filter entirely
            }}
            placeholder={`Type to search in ${preGlobalFilteredRows.length} inks`}
          />
        </div>
      </div>
    </div>
  );
};

const ActionsCell = ({
  id,
  archived,
  deletable,
  brand_name,
  line_name,
  ink_name,
  kind,
}) => {
  let inkName = [brand_name, line_name, ink_name].filter((c) => c).join(" ");
  if (kind) inkName += ` - ${kind}`;
  return (
    <td className="actions">
      <EditButton name={inkName} id={id} archived={archived} />
      <ArchiveButton name={inkName} id={id} archived={archived} />
      <DeleteButton
        name={inkName}
        id={id}
        deletable={deletable}
        archived={archived}
      />
    </td>
  );
};

const EditButton = ({ name, id, archived }) => {
  let href = `/collected_inks/${id}/edit`;
  if (archived) href += "?search[archive]=true";
  return (
    <span>
      <a className="btn btn-secondary" href={href} title={`Edit ${name}`}>
        <i className="fa fa-pencil" />
      </a>
    </span>
  );
};

const DeleteButton = ({ name, id, deletable, archived }) => {
  let href = `/collected_inks/${id}`;
  if (archived) href += "?search[archive]=true";
  if (!deletable) return null;
  return (
    <span>
      <a
        className="btn btn-secondary"
        data-confirm={`Really delete ${name}?`}
        title={`Delete ${name}`}
        data-method="delete"
        href={href}
      >
        <i className="fa fa-trash" />
      </a>
    </span>
  );
};

const ArchiveButton = ({ name, id, archived }) => {
  if (archived) {
    return (
      <span>
        <a
          className="btn btn-secondary"
          title={`Unarchive ${name}`}
          href={`/collected_inks/${id}/unarchive`}
          data-method="post"
        >
          <i className="fa fa-archive" />
        </a>
      </span>
    );
  } else {
    return (
      <span>
        <a
          className="btn btn-secondary"
          title={`Archive ${name}`}
          href={`/collected_inks/${id}/archive`}
          data-method="post"
        >
          <i className="fa fa-archive" />
        </a>
      </span>
    );
  }
};

const booleanSort = (rowA, rowB, columnId) => {
  if (rowA.values[columnId] == rowB.values[columnId]) return 0;
  if (rowA.values[columnId] && !rowB.values[columnId]) return 1;
  return -1;
};

const sortByColor = (rowA, rowB, columnId) =>
  colorSort(rowA.values[columnId], rowB.values[columnId]);

function fuzzyTextFilterFn(rows, id, filterValue) {
  const attrs = [
    "brand_name",
    "line_name",
    "ink_name",
    "maker",
    "comment",
    "private_comment",
  ];
  return matchSorter(rows, filterValue.replace(/\s+/gi, ""), {
    keys: [(row) => attrs.map((a) => row.values[a]).join("")],
  });
}
