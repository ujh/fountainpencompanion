import * as React from "react";
import { getRequest } from "src/fetch";
import Table from "./table";

export default class App extends React.Component {
  constructor(props) {
    super(props);
     this.state = { data: [] }
  }

  componentDidMount() {
    getRequest(location.href).then(
      response => response.json()
    ).then(
      json => this.processData(json)
    )
  }

  processData(jsonResponse) {
    let processedData = jsonResponse.included.filter(
      e => e.type == 'collected_inks'
    ).map(e => e.attributes);
    this.setState({data: processedData})
  }

  render() {
    return <Table data={this.state.data} />
  }
}
