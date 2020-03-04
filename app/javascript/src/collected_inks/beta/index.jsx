import React, { useState, useEffect, useMemo } from "react";
import * as ReactDOM from "react-dom";
import { useTable, useSortBy } from "react-table";
import { getRequest } from "src/fetch";

export const renderCollectedInksBeta = el => {
  ReactDOM.render(
    <CollectedInksBeta archive={el.getAttribute("data-archive") == "true"} />,
    el
  );
};

export default renderCollectedInksBeta;

const CollectedInksBeta = ({ archive }) => {
  const [inks, setInks] = useState();
  useEffect(() => {
    getRequest("/collected_inks.json")
      .then(response => response.json())
      .then(json => setInks(json.data));
  }, []);
  const nonArchived = useMemo(
    () => (inks || []).filter(i => i.attributes.archived == archive),
    [inks]
  );
  if (inks) {
    return <CollectedInksBetaTable data={nonArchived} />;
  } else {
    return (
      <div className="loader">
        <i className="fa fa-spin fa-refresh" />
      </div>
    );
  }
};

const CollectedInksBetaTable = ({ data }) => {
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
        }
      },
      {
        Header: "Brand",
        accessor: "attributes.brand_name"
      },
      {
        Header: "Line",
        accessor: "attributes.line_name"
      },
      {
        Header: "Name",
        accessor: "attributes.ink_name"
      },
      {
        Header: "Maker",
        accessor: "attributes.maker"
      },
      {
        Header: "Type",
        accessor: "attributes.kind"
      },
      {
        Header: "Color",
        accessor: "attributes.color",
        Cell: () => "",
        disableSortBy: true
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
        sortType: booleanSort
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
        sortType: booleanSort
      },
      {
        Header: "Usage",
        accessor: "attributes.usage"
      },
      {
        Header: "Comment",
        accessor: "attributes.comment"
      },
      {
        Header: "Private Comment",
        accessor: "attributes.private_comment"
      }
    ],
    [data]
  );
  const hiddenColumns = useMemo(
    () =>
      ["private_comment", "comment", "maker", "line_name", "kind"]
        .filter(n => !data.some(e => e.attributes[n]))
        .map(n => `attributes.${n}`),
    []
  );
  const {
    getTableProps,
    getTableBodyProps,
    headerGroups,
    rows,
    prepareRow
  } = useTable(
    {
      columns,
      data,
      initialState: {
        hiddenColumns
      }
    },
    useSortBy
  );
  return (
    <div className="table-responsive">
      <table {...getTableProps()} className="table table-striped">
        <thead>
          {headerGroups.map(headerGroup => (
            <tr {...headerGroup.getHeaderGroupProps()}>
              {headerGroup.headers.map(column => (
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
                {row.cells.map(cell => {
                  let additionalProps = {};
                  if (cell.column.id == "attributes.color" && cell.value) {
                    additionalProps = {
                      style: { backgroundColor: cell.value, width: "30px" }
                    };
                  }
                  return (
                    <td {...cell.getCellProps()} {...additionalProps}>
                      {cell.render("Cell")}
                    </td>
                  );
                })}
                <ActionsCell
                  {...row.original.attributes}
                  id={row.original.id}
                />
              </tr>
            );
          })}
        </tbody>
      </table>
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
  kind
}) => {
  let inkName = [brand_name, line_name, ink_name].filter(c => c).join(" ");
  if (kind) inkName += ` - ${kind}`;
  return (
    <td className="actions">
      <EditButton name={inkName} id={id} />
      <ArchiveButton name={inkName} id={id} archived={archived} />
      <DeleteButton name={inkName} id={id} deletable={deletable} />
    </td>
  );
};

const EditButton = ({ name, id }) => (
  <span>
    <a
      className="btn btn-default"
      href={`/collected_inks/beta/${id}/edit`}
      title={`Edit ${name}`}
    >
      <i className="fa fa-pencil" />
    </a>
  </span>
);

const DeleteButton = ({ name, id, deletable }) => {
  if (!deletable) return null;
  return (
    <span>
      <a
        className="btn btn-default"
        data-confirm={`Really delete ${name}?`}
        title={`Delete ${name}`}
        data-method="delete"
        href={`/collected_inks/beta/${id}`}
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
          href={`/collected_inks/beta/${id}/unarchive`}
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
          href={`/collected_inks/beta/${id}/archive`}
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
