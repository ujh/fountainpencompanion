import * as React from "react";
import { getRequest } from "src/fetch";
import Table from "./table";

export default class App extends React.Component {
  constructor(props) {
    super(props);
     this.state = { userData: [] }
  }

  componentDidMount() {
    getUserData(data => this.setState({userData: data}))
  }

  tableData() {
    return this.state.userData;
  }

  render() {
    return <Table data={this.tableData()} />
  }
}

function getUserData(callback) {
  getRequest(location.href).then(
    response => response.json()
  ).then(
    json => callback(processData(json))
  )
}

function processData(data) {
  let processedData = data.included.filter(
    e => e.type == 'collected_inks'
  ).map(e => e.attributes);
  return processedData;
}
