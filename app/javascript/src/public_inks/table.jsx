import * as React from "react";
import ReactTable from "react-table-6";
import _ from "lodash";

export default class Table extends React.Component {
  constructor(props) {
    super(props);
    this.state = {};
  }

  calculateWidth = () => {
    this.setState({ width: window.innerWidth });
  };

  componentDidMount() {
    this.calculateWidth();
    window.addEventListener("resize", this.calculateWidth);
  }

  componentWillUnmount() {
    window.removeEventListener("resize", this.calculateWidth);
  }

  hiddenColumns() {
    let hidden = [];
    let width = this.state.width;
    if (width <= 768) hidden.push("line_name");
    if (width <= 992) hidden.push("maker");
    if (width <= 1200) hidden.push("comment");
    return hidden;
  }

  showColumn(column) {
    return !this.hiddenColumns().includes(column);
  }

  comparisonConfig() {
    return {
      Header: "Compare",
      accessor: "comparison",
      show: this.props.additionalData,
      minWidth: 30,
      sortable: false,
      filterMethod: (filter, row) => {
        let od = row._original;
        if (filter.value == "all") {
          return od.owned_by_user;
        }
        if (filter.value == "you") {
          return od.owned_by_logged_in_user && !od.owned_by_user;
        }
        if (filter.value == "other") {
          return !od.owned_by_logged_in_user && od.owned_by_user;
        }
      },
      Cell: (row) => (
        <ComparisonCell {...row.original} name={this.props.name} />
      ),
      Filter: (props) => <ComparisonFilter {...props} name={this.props.name} />
    };
  }

  brandConfig() {
    return {
      ...this.defaultConfig("brand_name"),
      minWidth: 100,
      Footer: ({ data }) => {
        let count = _.uniq(data.map((e) => e.brand_name)).length;
        let word = count == 1 ? "brand" : "brands";
        return (
          <strong>
            {count} {word}
          </strong>
        );
      }
    };
  }

  lineConfig() {
    return {
      ...this.defaultConfig("line_name"),
      minWidth: 50
    };
  }

  inkConfig() {
    return {
      ...this.defaultConfig("ink_name"),
      Cell: ({ value, original: { ink_id } }) => {
        return (
          <>
            <span title={value}>{value}</span>
            {ink_id && (
              <a href={`/inks/${ink_id}`}>
                &nbsp;
                <i className="fa fa-external-link" />
              </a>
            )}
          </>
        );
      },
      minWidth: 100,
      Footer: ({ data }) => {
        let count = data.length;
        let word = count == 1 ? "ink" : "inks";
        return (
          <strong>
            {count} {word}
          </strong>
        );
      }
    };
  }

  makerConfig() {
    return {
      ...this.defaultConfig("maker"),
      minWidth: 50
    };
  }

  typeConfig() {
    return {
      ...this.defaultConfig("kind"),
      minWidth: 40,
      style: { textAlign: "center" },
      Filter: (props) => <TypeFilter {...props} />,
      Footer: ({ data }) => {
        let stats = _.groupBy(data.map((e) => e.kind || "unknown"));
        if (Object.keys(stats).length > 1) {
          return Object.keys(stats)
            .sort()
            .map((k) => (
              <div key={k}>
                <strong>
                  {stats[k].length}x {k}
                </strong>
              </div>
            ));
        }
        return <span></span>;
      }
    };
  }

  colorConfig() {
    return {
      accessor: "color",
      Cell: (props) => (
        <div
          style={{
            backgroundColor: props.value,
            width: "100%",
            height: "100%"
          }}
        />
      ),
      style: { padding: 0 },
      width: 37,
      filterable: false,
      sortable: false
    };
  }

  commentConfig() {
    return {
      ...this.defaultConfig("comment"),
      minWidth: 50
    };
  }

  defaultConfig(accessor) {
    return {
      Header: columnDisplayName(accessor),
      accessor,
      Cell: ({ value }) => <span title={value}>{value}</span>,
      show: this.showColumn(accessor)
    };
  }

  columnConfig() {
    return [
      this.comparisonConfig(),
      this.brandConfig(),
      this.lineConfig(),
      this.inkConfig(),
      this.makerConfig(),
      this.typeConfig(),
      this.colorConfig(),
      this.commentConfig()
    ];
  }

  tableProps() {
    let props = {
      columns: this.columnConfig(),
      data: this.props.data,
      defaultFilterMethod: (filter, row) => {
        let rowData = row[filter.id].replace(/\W/g, "");
        let searchData = filter.value.replace(/\W/g, "");
        return rowData.match(new RegExp(searchData, "i"));
      },
      defaultSorted: [
        { id: "brand_name" },
        { id: "line_name" },
        { id: "ink_name" }
      ],
      filterable: true
    };
    let hidden = this.hiddenColumns();
    if (hidden.length) {
      props.SubComponent = (row) => (
        <RowSubComponent row={row} hidden={hidden} />
      );
    } else {
      // Necessary to clear out the previous value on resize
      props.SubComponent = null;
    }
    return props;
  }
  render() {
    return <ReactTable {...this.tableProps()} />;
  }
}

const columnDisplayName = (accessor) => {
  let data = {
    brand_name: "Brand",
    comment: "Comment",
    ink_name: "Ink",
    kind: "Type",
    line_name: "Line",
    maker: "Maker"
  };
  return data[accessor] || accessor;
};

const RowSubComponent = ({ row, hidden }) => {
  let data = hidden.sort().map((c) => ({ column: c, value: row.row[c] }));
  return (
    <div style={{ padding: "20px" }}>
      <ReactTable
        columns={[
          {
            Header: "Column",
            accessor: "column",
            Cell: (row) => <strong>{columnDisplayName(row.value)}</strong>,
            minWidth: 20
          },
          {
            Header: "Value",
            accessor: "value"
          }
        ]}
        data={data}
        defaultSorted={[{ id: "column" }]}
        minRows={data.length}
        showPagination={false}
      />
    </div>
  );
};

class ComparisonFilter extends React.Component {
  value() {
    if (this.props.filter) return this.props.filter.value;
    return "all";
  }

  componentDidMount() {
    this.props.onChange(this.value());
  }

  render() {
    return (
      <select
        onChange={(event) => this.props.onChange(event.target.value)}
        style={{ width: "100%" }}
        value={this.value()}
      >
        <option value="all">All of {this.props.name}'s inks</option>
        <option value="you">Inks only you own</option>
        <option value="other">Inks only {this.props.name} owns</option>
      </select>
    );
  }
}

class TypeFilter extends React.Component {
  value() {
    if (this.props.filter) return this.props.filter.value;
    return "all";
  }

  render() {
    return (
      <select
        onChange={(event) => this.props.onChange(event.target.value)}
        style={{ width: "100%" }}
        value={this.value()}
      >
        <option value="all">All</option>
        <option value="bottle">bottle</option>
        <option value="cartridge">cartridge</option>
        <option value="sample">sample</option>
        <option value="swab">swab</option>
        <option value="unknown">unknown</option>
      </select>
    );
  }
}

const ComparisonCell = ({ name, owned_by_user, owned_by_logged_in_user }) => {
  if (owned_by_user) {
    if (owned_by_logged_in_user) {
      return "both";
    }
    return name;
  }
  return "you";
};
