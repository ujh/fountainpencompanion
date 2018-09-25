import * as React from "react";
import ReactTable from "react-table";
import _ from "lodash";

export default class Table extends React.Component {
  constructor(props) {
    super(props);
    this.state = {}
  }

  calculateWidth = () => {
    this.setState({width: window.innerWidth})
  }

  componentDidMount() {
    this.calculateWidth()
    window.addEventListener('resize', this.calculateWidth)
  }

  componentWillUnmount() {
    window.removeEventListener('resize', this.calculateWidth)
  }

  columnConfig() {
    let config = [{
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
          return od.owned_by_logged_in_user && !od.owned_by_user
        }
        if (filter.value == "other") {
          return !od.owned_by_logged_in_user && od.owned_by_user
        }
      },
      Cell: (row) => <ComparisonCell {...row.original} name={this.props.logged_in_user_name}/>,
      Filter: (props) => <ComparisonFilter {...props} name={this.props.logged_in_user_name} />
    }, {
      Header: "Brand",
      accessor: 'brand_name',
      minWidth: 100,
      Cell: ({value}) => <span title={value}>{value}</span>,
      Footer: ({data}) => {
        let count = _.uniq(data.map(e => e.brand_name)).length;
        let word = count == 1 ? 'brand' : 'brands';
        return <strong>{count} {word}</strong>
      }
    }, {
      Header: "Line",
      accessor: "line_name",
      minWidth: 50,
      Cell: ({value}) => <span title={value}>{value}</span>,
      show: this.state.width > 768
    }, {
      Header: "Ink",
      accessor: "ink_name",
      minWidth: 100,
      Footer: ({data}) => {
        let count = data.length;
        let word = count == 1 ? 'ink' : 'inks';
        return <strong>{count} {word}</strong>
      },
      Cell: ({value}) => <span title={value}>{value}</span>,
    }, {
      Header: "Maker",
      accessor: "maker",
      minWidth: 50,
      className: 'maker',
      Cell: ({value}) => <span title={value}>{value}</span>,
      show: this.state.width > 992
    }, {
      Header: "Type",
      accessor: "kind",
      minWidth: 40,
      style: {textAlign: 'center'},
      Cell: ({value}) => <span title={value}>{value}</span>,
      Footer: ({data}) => {
        let stats = _.groupBy(data.map(e => e.kind));
        if (Object.keys(stats).length > 1) {
          return Object.keys(stats).map(k => <div key={k}><strong>{stats[k].length}x {k}</strong></div>)
        }
        return <span></span>;
      }
    }, {
      accessor: "color",
      Cell: props => <div style={{backgroundColor: props.value, width: '100%', height: '100%'}} />,
      style: {padding: 0},
      width: 37,
      filterable: false,
      sortable: false,
    }, {
      Header: "Comment",
      accessor: "comment",
      minWidth: 50,
      Cell: ({value}) => <span title={value}>{value}</span>,
      show: this.state.width > 1200
    }]
    return config;
  }

  render() {
    let data = this.props.data;
    return <ReactTable
    columns={this.columnConfig()}
    data={data}
    defaultFilterMethod={(filter, row) => {
      let rowData = row[filter.id].replace(/\W/g, '')
      let searchData = filter.value.replace(/\W/g, '')
      return rowData.match(new RegExp(searchData, 'i'))
    }}
    defaultSorted={[{id: "brand_name"}, {id: "line_name"}, {id: "ink_name"}]}
    filterable={true}
  />
  }
}

class ComparisonFilter extends React.Component {

  value() {
    if (this.props.filter) return this.props.filter.value;
    return "all"
  }

  componentDidMount() {
    this.props.onChange(this.value())
  }

  render() {
    return <select
      onChange={event => this.props.onChange(event.target.value)}
      style={{ width: "100%" }}
      value={this.value()}
    >
      <option value="all">All of {this.props.name}'s inks</option>
      <option value="you">Inks only you own</option>
      <option value="other">Inks only {this.props.name} owns</option>
    </select>
  }
}

const ComparisonCell = ({name, owned_by_user, owned_by_logged_in_user}) => {
  if (owned_by_user) {
    if (owned_by_logged_in_user) {
      return "both"
    }
    return name
  }
  return "you"
}
