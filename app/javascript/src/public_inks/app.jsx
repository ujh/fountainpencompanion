import * as React from "react";
import { getRequest } from "src/fetch";
import Table from "./table";

export default class App extends React.Component {
  constructor(props) {
    super(props);
     this.state = {
       userData: { user_id: null, inks: [] },
       loggedInUserData: { user_id: null, inks: [] }
      }
  }

  componentDidMount() {
    getUserData(data => this.setState({userData: data}))
    getloggedInUserData(data => this.setState({loggedInUserData: data}))
  }

  tableData() {
    let ld = this.state.loggedInUserData;
    let ud = this.state.userData;
    if (ld.user_id && ld.user_id != ud.user_id) {
      console.log('additional data')
    }
    return ud.inks;
  }

  render() {
    return <Table data={this.tableData()} />
  }
}

function getloggedInUserData(callback) {
  getRequest("/account").then(
    response => {
      if (response.ok) {
        response.json().then(json => callback(processData(json)))
      }
    }
  )
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
  return { user_id: data.data.id, inks: processedData};
}
