import * as React from "react";
import { connect } from "react-redux";

import Filters from "./filters";
import InkTable from "./ink_table";

const mapStateToProps = ({ archived }) => ({ ...archived });

const ArchivedCollectedInks = ({brands, entries, stats}) => <div className="ink-collection">
  <h1>Archive</h1>
  <Filters brands={brands} />
  <InkTable entries={entries} stats={stats} />
</div>;

export default connect(mapStateToProps)(ArchivedCollectedInks);
