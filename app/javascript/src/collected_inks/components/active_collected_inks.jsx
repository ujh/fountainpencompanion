import * as React from "react";
import { connect } from "react-redux";

import Filters from "./filters";
import InkTable from "./ink_table";
import { updateFilterAndRecalculate } from "src/collected_inks/actions";

const mapDispatchToProps = dispatch => ({
  onChange(event) {
    const brand_name = event.target.value;
    dispatch(updateFilterAndRecalculate({filterName: "active", filterValue: brand_name, filterField: "brand_name"}))
  }
})
const mapStateToProps = ({ active }) => ({ ...active });

const ActiveCollectedInks = ({brands, entries, stats, onChange}) => <div className="ink-collection">
  <Filters brands={brands} onChange={onChange} />
  <InkTable newEntryForm entries={entries} stats={stats} />
</div>;

export default connect(mapStateToProps, mapDispatchToProps)(ActiveCollectedInks);
