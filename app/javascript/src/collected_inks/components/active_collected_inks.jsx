import * as React from "react";
import { connect } from "react-redux";

import Filters from "./filters";
import InkTable from "./ink_table";

const mapStateToProps = ({ active }) => ({ ...active });

const ActiveCollectedInks = ({brands, entries, stats}) => <div className="ink-collection">
  <Filters brands={brands} />
  <InkTable entries={entries} stats={stats} />
</div>;

export default connect(mapStateToProps)(ActiveCollectedInks);
