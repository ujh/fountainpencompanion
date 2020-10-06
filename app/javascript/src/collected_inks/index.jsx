import React, { useState, useEffect, useMemo } from "react";
import * as ReactDOM from "react-dom";
import { useTable, useSortBy, useGlobalFilter } from "react-table";
import convert from "color-convert";
import matchSorter from "match-sorter";
import _ from "lodash";
import { getRequest } from "src/fetch";

document.addEventListener("DOMContentLoaded", () => {
  const elements = document.querySelectorAll("#collected-inks .app");
  Array.from(elements).forEach((el) => {
    ReactDOM.render(
      <CollectedInks archive={el.getAttribute("data-archive") == "true"} />,
      el
    );
  });
});

const CollectedInks = ({ archive }) => {
  const [inks, setInks] = useState();
  useEffect(() => {
    getRequest("/collected_inks.json")
      .then((response) => response.json())
      .then((json) => setInks(json.data));
  }, []);
  const nonArchived = useMemo(
    () => (inks || []).filter((i) => i.attributes.archived == archive),
    [inks]
  );
  if (inks) {
    return <CollectedInksBetaTable data={nonArchived} archive={archive} />;
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
      original: {
        attributes: { ink_id },
      },
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

const CollectedInksBetaTable = ({ data, archive }) => {
  const columns = useMemo(
    () => [
      {
        accessor: "attributes.private",
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
        accessor: "attributes.brand_name",
        Footer: (info) => {
          const count = useMemo(() => {
            return _.uniqBy(
              info.rows,
              (row) => row.values["attributes.brand_name"]
            ).length;
          }, [info.rows]);
          return <span>{count} brands</span>;
        },
      },
      {
        Header: "Line",
        accessor: "attributes.line_name",
      },
      {
        Header: "Name",
        accessor: "attributes.ink_name",
        Cell: renderInkWithLink,
        Footer: (info) => {
          return <span>{info.rows.length} inks</span>;
        },
      },
      {
        Header: "Maker",
        accessor: "attributes.maker",
      },
      {
        Header: "Type",
        accessor: "attributes.kind",
        Footer: (info) => {
          const counters = useMemo(() => {
            return _.countBy(info.rows, (row) => row.values["attributes.kind"]);
          });
          return (
            <span>
              <span className="counter">{counters.bottle || 0}x bottle</span>
              <br />
              <span className="counter">{counters.sample || 0}x sample</span>
              <br />
              <span className="counter">
                {counters.cartridge || 0}x cartridge
              </span>
            </span>
          );
        },
      },
      {
        Header: "Color",
        accessor: "attributes.color",
        Cell: () => "",
        sortType: colorSort,
      },
      {
        Header: "Swabbed",
        accessor: "attributes.swabbed",
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
        accessor: "attributes.used",
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
        accessor: "attributes.usage",
        sortDescFirst: true,
      },
      {
        Header: "Daily Usage",
        accessor: "attributes.daily_usage",
        sortDescFirst: true,
      },
      {
        Header: "Comment",
        accessor: "attributes.comment",
      },
      {
        Header: "Private Comment",
        accessor: "attributes.private_comment",
      },
    ],
    [data]
  );
  const hiddenColumns = useMemo(
    () =>
      [
        "private_comment",
        "comment",
        "maker",
        "line_name",
        "kind",
        "daily_usage",
      ]
        .filter((n) => !data.some((e) => e.attributes[n]))
        .map((n) => `attributes.${n}`),
    []
  );
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

const Table = ({
  getTableProps,
  headerGroups,
  footerGroups,
  getTableBodyProps,
  rows,
  prepareRow,
}) => (
  <div className="table-wrapper">
    <table {...getTableProps()} className="table table-striped table-condensed">
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
                if (cell.column.id == "attributes.color" && cell.value) {
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
              <ActionsCell {...row.original.attributes} id={row.original.id} />
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
          <div className="col-xs-12 col-sm-2 col-md-2">
            <a className="btn btn-primary" href="/collected_inks/new">
              Add Ink
            </a>
          </div>
          <div className="col-xs-12 col-sm-2 col-md-2">
            <a
              className="btn btn-default"
              href="/collected_inks?search[archive]=true"
            >
              Archive
            </a>
          </div>
        </>
      )}
      <div className={archive ? "col-xs-12" : "col-xs-12 col-sm-8 col-md-8"}>
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
      <a className="btn btn-default" href={href} title={`Edit ${name}`}>
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
        className="btn btn-default"
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
          className="btn btn-default"
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
          className="btn btn-default"
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

const colorSort = (rowA, rowB, columnId) => {
  if (!rowA.values[columnId]) return 1;
  if (!rowB.values[columnId]) return -1;
  const colorA = hexToSortArray(rowA.values[columnId]);
  const colorB = hexToSortArray(rowB.values[columnId]);
  let r = sortByElement(colorA, colorB, 0);
  if (r) return r;
  r = sortByElement(colorA, colorB, 1);
  if (r) return r;
  return sortByElement(colorA, colorB, 2);
};

const sortByElement = (arrayA, arrayB, i) => {
  if (arrayA[i] == arrayB[i]) return 0;
  return arrayA[i] < arrayB[i] ? -1 : 1;
};

// See https://www.alanzucconi.com/2015/09/30/colour-sorting/
const hexToSortArray = (hex) => {
  const repetitions = 8;
  const [r, g, b] = convert.hex.rgb(hex);
  const lum = Math.sqrt(0.241 * r + 0.691 * g + 0.068 * b);
  const [h, s, v] = convert.hex.hsv(hex);
  const h2 = Math.round(h * repetitions);
  let lum2 = Math.round(lum * repetitions);
  let v2 = Math.round(v * repetitions);
  if (h2 % 2 == 1) {
    v2 = repetitions - v2;
    lum2 = repetitions - lum2;
  }
  return [h2, lum2, v2];
};

function fuzzyTextFilterFn(rows, id, filterValue) {
  const attrs = [
    "attributes.brand_name",
    "attributes.line_name",
    "attributes.ink_name",
    "attributes.maker",
    "attributes.comment",
    "attributes.private_comment",
  ];
  return matchSorter(rows, filterValue.replace(/\s+/gi, ""), {
    keys: [(row) => attrs.map((a) => row.values[a]).join("")],
  });
}
