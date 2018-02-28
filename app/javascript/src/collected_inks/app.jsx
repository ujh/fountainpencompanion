import * as React from "react";
import { connect } from "react-redux";

import CollectedInks from "./components/collected_inks";
import Loading from "./components/loading";

const mapStateToProps = ({loading}) => ({loading});

const App = ({loading}) => <div>
  {loading ? <Loading /> : <CollectedInks />}
</div>;

export default connect(mapStateToProps)(App);
