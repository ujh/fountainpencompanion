import * as React from "react";
import { connect } from "react-redux";

import InkTable from "./ink_table";

const mapStateToProps = ({ archived }) => ({ entries: archived });

const ArchivedCollectedInks = ({entries}) => <div>
  <h1>Archive</h1>
  <InkTable entries={entries} />
</div>;

export default connect(mapStateToProps)(ArchivedCollectedInks);
