import * as React from "react";
import { connect } from "react-redux";

import Filters from "./filters";
import InkTable from "./ink_table";
import { updateFilterAndRecalculate } from "src/collected_inks/actions";

const mapDispatchToProps = dispatch => ({
  onChange(event) {
    const brand_name = event.target.value;
    dispatch(updateFilterAndRecalculate({filterName: "archived", filterValue: brand_name, filterField: "brand_name"}))
  }
})

const mapStateToProps = ({ archived }) => ({ ...archived });

const ArchivedCollectedInks = ({brands, entries, stats, onChange}) => <div className="ink-collection">
  <h1>Archive</h1>
    <Filters brands={brands} onChange={onChange} />
  <InkTable entries={entries} stats={stats} />
</div>;

export default connect(mapStateToProps, mapDispatchToProps)(ArchivedCollectedInks);
