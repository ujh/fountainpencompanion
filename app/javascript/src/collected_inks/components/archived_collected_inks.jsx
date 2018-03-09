import * as React from "react";
import { connect } from "react-redux";

import InkTable from "./ink_table";

const mapStateToProps = ({ archived }) => ({ ...archived });

const ArchivedCollectedInks = (props) => <div>
  <h1>Archive</h1>
  <InkTable {...props} />
</div>;

export default connect(mapStateToProps)(ArchivedCollectedInks);
