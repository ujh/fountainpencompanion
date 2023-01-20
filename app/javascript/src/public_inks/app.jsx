import * as React from "react";
import { getRequest } from "../fetch";
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
    getUserData(data => this.setState({userData: data})).then(
      () => getloggedInUserData(data => this.setState({loggedInUserData: data}))
    )
  }

  tableData() {
    let ld = this.state.loggedInUserData;
    let ud = this.state.userData;
    let additionalData = ld.user_id && ld.user_id != ud.user_id;
    if (additionalData) {
      let combined = [];
      let userInks = new Set(ud.inks.map(i => i.ink_id))
      let loggedInUserInks = new Set(ld.inks.map(i => i.ink_id))
      ud.inks.forEach(ink => {
        let comparison = this.calculateComparison(ink.ink_id, userInks, loggedInUserInks)
        combined.push({...ink, ...comparison})
      })
      ld.inks.forEach(ink => {
        let comparison = this.calculateComparison(ink.ink_id, userInks, loggedInUserInks)
        // User already owns ink, no need to add it again
        if (!comparison.owned_by_user) combined.push({...ink, ...comparison})
      })
      return {data: combined, additionalData, name: ud.name};
    } else {
      return {data: ud.inks, additionalData};
    }
  }

  calculateComparison(id, userInks, loggedInUserInks) {
    return {
      owned_by_user: userInks.has(id),
      owned_by_logged_in_user: loggedInUserInks.has(id)
    }
  }

  render() {
    return <Table {...this.tableData()} />
  }
}

function getloggedInUserData(callback) {
  return getRequest("/account").then(
    response => {
      if (response.ok) {
        response.json().then(json => callback(processData(json)))
      }
    }
  )
}

function getUserData(callback) {
  return getRequest(location.href).then(
    response => response.json()
  ).then(
    json => callback(processData(json))
  )
}

function processData(data) {
  let processedData = data.included.filter(
    e => e.type == 'collected_inks'
  ).map(e => e.attributes);
  return { user_id: data.data.id, name: data.data.attributes.name, inks: processedData};
}
